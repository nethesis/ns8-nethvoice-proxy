#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

"""Run with: python3 -m unittest discover -s tests/integration -v

Requires Podman and the images below (override with the corresponding *_IMAGE
variables). Containers are disposable and have no external network access.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[2]
KAMAILIO_IMAGE = os.getenv('KAMAILIO_IMAGE', 'ghcr.io/nethesis/nethvoice-proxy-kamailio:1.7.1')
PYTHON_IMAGE = os.getenv('PYTHON_IMAGE', 'docker.io/library/python:3.13.15-alpine')
SOURCE = (ROOT / 'modules/kamailio/config/kamailio.cfg').read_text()

# route[RELAY], route[SET_TIMERS] and onreply_route[MANAGE_REPLY] come from
# kamailio.cfg. The request route takes the direction from an X-Direction
# header and marks trunk OPTIONS with X-Trunk, as NV_TRUNK_OPT_TAG does; the
# store route adds the code it would save to the reply. The timers are
# shortened to keep the test fast.
CONFIG = '''#!KAMAILIO
#!define FR_TIMEOUT 3000
#!define FR_TIMEOUT_OPTIONS 2000
#!define FR_TIMEOUT_100 1000
#!define FR_INV_TIMEOUT 120000
#!define FR_TIMEOUT_BYE 3000
#!define FR_TIMEOUT_NOTIFY 5000
#!define INTERNAL_NETWORK "10.5.4.0/24"
log_stderror=yes
debug=1
children=1
listen=udp:127.0.0.1:15060
mpath="/usr/lib/x86_64-linux-gnu/kamailio/modules/"
loadmodule "kex.so"
loadmodule "pv.so"
loadmodule "xlog.so"
loadmodule "sl.so"
loadmodule "tm.so"
loadmodule "textops.so"
loadmodule "htable.so"
loadmodule "ipops.so"
loadmodule "rr.so"
loadmodule "dialog.so"
modparam("htable", "htable", "nvtrunkopt=>size=4;")
modparam("tm", "fr_timer", FR_TIMEOUT_100)
request_route {
    $avp(direction) = $hdr(X-Direction);
    $avp(req_direction) = $avp(direction);
    if (is_method("REGISTER")) {
        $avp(nv_trunkreg) = "1";
    }
    if (is_method("OPTIONS") && is_present_hf("X-Trunk")) {
        $avp(nv_trunkopt) = "1";
    }
    route(SET_TIMERS);
    route(RELAY);
    exit;
}
route[NV_TRUNK_REG_STORE] {
    append_to_reply("X-Nv-Code: $var(nv_code)\\r\\n");
}
route[NV_TRUNK_REG_REPLY] {
    return;
}
route[NV_DEVICE_REG_REPLY] {
    return;
}
route[NV_TRUNK_OPT_STORE] {
    return;
}
route[NATMANAGE] {
    return;
}
branch_route[MANAGE_BRANCH] {
    return;
}
failure_route[MANAGE_FAILURE] {
    return;
}
'''

# Sends one request to the proxy and prints the final reply. With a delay, a
# provider on 127.0.0.1:15099 (the loopback, as a provider in the internal
# network) answers 100 Trying at once to REGISTER, and 200 OK after the delay.
CLIENT = '''
import json
import socket
import sys
import threading
import time

method, uri, direction, trunk, delay, tag = json.load(sys.stdin)

def provider():
    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.bind(('127.0.0.1', 15099))
    seen = set()
    while True:
        data, address = server.recvfrom(65535)
        lines = data.decode().split('\\r\\n')
        headers = [line for line in lines[1:] if line.split(':', 1)[0] in ('Via', 'From', 'To', 'Call-ID', 'CSeq')]
        if headers[0] in seen:
            continue
        seen.add(headers[0])
        def reply(code, text, to_tag):
            fields = [h + (';tag=p1' if to_tag and h.startswith('To:') else '') for h in headers]
            message = f'SIP/2.0 {code} {text}\\r\\n' + '\\r\\n'.join(fields) + '\\r\\nContent-Length: 0\\r\\n\\r\\n'
            server.sendto(message.encode(), address)
        if lines[0].startswith('REGISTER'):
            reply(100, 'Trying', False)
        threading.Timer(delay, reply, (200, 'OK', True)).start()

if delay is not None:
    threading.Thread(target=provider, daemon=True).start()
    time.sleep(0.2)
client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
client.bind(('127.0.0.1', 15090))
client.settimeout(15)
request = (f'{method} {uri} SIP/2.0\\r\\n'
           f'Via: SIP/2.0/UDP 127.0.0.1:15090;branch=z9hG4bK-relay-{tag}\\r\\n'
           'From: <sip:user@example.org>;tag=a1\\r\\nTo: <sip:user@example.org>\\r\\n'
           f'Call-ID: relay-{tag}\\r\\nCSeq: 1 {method}\\r\\n'
           'Contact: <sip:user@127.0.0.1:15090>\\r\\n'
           f'X-Direction: {direction}\\r\\n'
           + ('X-Trunk: 1\\r\\n' if trunk else '') +
           'Max-Forwards: 70\\r\\nContent-Length: 0\\r\\n\\r\\n')
start = time.monotonic()
client.sendto(request.encode(), ('127.0.0.1', 15060))
while True:
    reply = client.recv(65535).decode()
    status = int(reply.split(' ', 2)[1])
    if status >= 200:
        break
headers = dict(line.split(': ', 1) for line in reply.split('\\r\\n')[1:] if ': ' in line)
print(json.dumps([status, reply.split('\\r\\n')[0], headers.get('X-Nv-Code'), time.monotonic() - start]))
'''


def extract(header, end='} # end'):
    start = SOURCE.index(header)
    return SOURCE[start:SOURCE.index(end, start) + 1]


class RelayErrorsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.podman = shutil.which('podman')
        if not cls.podman:
            raise unittest.SkipTest('Podman is required')
        cls.directory = tempfile.TemporaryDirectory(prefix='relay-')
        cls.addClassCleanup(cls.directory.cleanup)
        routes = [extract('route[RELAY] {'), extract('route[SET_TIMERS] {'),
                  extract('onreply_route[MANAGE_REPLY] {')]
        config_path = Path(cls.directory.name) / 'kamailio.cfg'
        config_path.write_text(CONFIG + '\n'.join(routes) + '\n')
        cls.container = 'relay-' + uuid.uuid4().hex[:10]
        subprocess.run([cls.podman, 'run', '-d', '--network', 'none', '--name', cls.container,
                        '-v', str(config_path) + ':/tmp/test.cfg:ro,Z',
                        '--entrypoint', '/usr/sbin/kamailio', KAMAILIO_IMAGE,
                        '-DD', '-E', '-f', '/tmp/test.cfg'], check=True, capture_output=True)
        cls.addClassCleanup(subprocess.run, [cls.podman, 'rm', '-f', cls.container],
                            check=True, capture_output=True)

    def send(self, method, uri, direction, trunk=False, delay=None):
        """Send a request and return the final status, status line, stored
        code and seconds waited. With a delay, a provider on the loopback
        answers 200 OK after it."""
        result = subprocess.run([self.podman, 'run', '--rm', '-i', '--network', 'container:' + self.container,
                                 PYTHON_IMAGE, 'python3', '-c', CLIENT],
                                input=json.dumps([method, uri, direction, trunk, delay, uuid.uuid4().hex]),
                                text=True, capture_output=True, timeout=60)
        logs = subprocess.run([self.podman, 'logs', self.container], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr + logs.stderr)
        return json.loads(result.stdout)

    def test_unresolvable_destination_gets_503(self):
        status, line, stored, _ = self.send('REGISTER', 'sip:sip.unresolvable.invalid:5060', 'out')
        self.assertEqual(status, 503, line)
        self.assertEqual(stored, '408')

    def test_outbound_register_waits_for_the_provider(self):
        # Nothing listens on the port: no answer, tm replies 408 on timeout
        status, line, _, waited = self.send('REGISTER', 'sip:127.0.0.1:15099', 'out')
        self.assertEqual(status, 408, line)
        self.assertGreaterEqual(waited, 2.5)

    def test_outbound_register_keeps_waiting_after_a_provisional_reply(self):
        # MANAGE_REPLY sees 100 Trying from the loopback, sets the direction
        # to "in" and runs SET_TIMERS again
        status, line, _, waited = self.send('REGISTER', 'sip:127.0.0.1:15099', 'out', delay=1.8)
        self.assertEqual(status, 200, line)
        self.assertGreaterEqual(waited, 1.8)

    def test_inbound_register_keeps_the_short_timeout(self):
        status, line, _, waited = self.send('REGISTER', 'sip:127.0.0.1:15099', 'in')
        self.assertEqual(status, 408, line)
        self.assertLess(waited, 2.5)

    def test_trunk_options_waits_for_a_slow_provider(self):
        status, line, _, _ = self.send('OPTIONS', 'sip:127.0.0.1:15099', 'out', trunk=True, delay=1.5)
        self.assertEqual(status, 200, line)

    def test_trunk_options_timeout_stays_below_the_asterisk_qualify_timeout(self):
        status, line, _, waited = self.send('OPTIONS', 'sip:127.0.0.1:15099', 'out', trunk=True)
        self.assertEqual(status, 408, line)
        self.assertGreaterEqual(waited, 1.5)
        self.assertLess(waited, 3)

    def test_request_route_sets_the_timers_of_trunk_options(self):
        block = extract('route(NV_TRUNK_OPT_TAG);', 'exit;')
        self.assertLess(block.index('route(SET_TIMERS);'), block.index('route(RELAY);'))
        self.assertIn('$avp(req_direction) = $avp(direction);', extract('request_route {', '} # end request_route'))


if __name__ == '__main__':
    unittest.main()
