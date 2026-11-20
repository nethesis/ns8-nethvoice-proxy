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

# route[RELAY] and route[SET_TIMERS] come from kamailio.cfg. The request route
# takes the direction from an X-Direction header; the store routes add the
# code they would save to the reply. FR_TIMEOUT is shortened to keep the
# test fast.
CONFIG = '''#!KAMAILIO
#!define FR_TIMEOUT 3000
#!define FR_TIMEOUT_100 1000
#!define FR_INV_TIMEOUT 120000
#!define FR_TIMEOUT_BYE 3000
#!define FR_TIMEOUT_NOTIFY 5000
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
modparam("htable", "htable", "nvtrunkopt=>size=4;")
modparam("tm", "fr_timer", FR_TIMEOUT_100)
request_route {
    $avp(direction) = $hdr(X-Direction);
    $avp(nv_trunkreg) = "1";
    route(SET_TIMERS);
    route(RELAY);
    exit;
}
route[NV_TRUNK_REG_STORE] {
    append_to_reply("X-Nv-Code: $var(nv_code)\\r\\n");
}
route[NV_TRUNK_OPT_STORE] {
    return;
}
branch_route[MANAGE_BRANCH] {
    return;
}
onreply_route[MANAGE_REPLY] {
    return;
}
failure_route[MANAGE_FAILURE] {
    return;
}
'''

CLIENT = '''
import json
import socket
import sys
import time

uri, direction, tag = json.load(sys.stdin)
client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
client.bind(('127.0.0.1', 15090))
client.settimeout(15)
request = (f'REGISTER {uri} SIP/2.0\\r\\n'
           f'Via: SIP/2.0/UDP 127.0.0.1:15090;branch=z9hG4bK-relay-{tag}\\r\\n'
           'From: <sip:user@example.org>;tag=a1\\r\\nTo: <sip:user@example.org>\\r\\n'
           f'Call-ID: relay-{tag}\\r\\nCSeq: 1 REGISTER\\r\\n'
           'Contact: <sip:user@127.0.0.1:15090>\\r\\n'
           f'X-Direction: {direction}\\r\\n'
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


class RelayErrorsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.podman = shutil.which('podman')
        if not cls.podman:
            raise unittest.SkipTest('Podman is required')
        cls.directory = tempfile.TemporaryDirectory(prefix='relay-')
        cls.addClassCleanup(cls.directory.cleanup)
        source = (ROOT / 'modules/kamailio/config/kamailio.cfg').read_text()
        routes = []
        for name in ('RELAY', 'SET_TIMERS'):
            start = source.index('route[%s] {' % name)
            end = source.index('} # end', start) + 1
            routes.append(source[start:end])
        config_path = Path(cls.directory.name) / 'kamailio.cfg'
        config_path.write_text(CONFIG + '\n'.join(routes) + '\n')
        cls.container = 'relay-' + uuid.uuid4().hex[:10]
        subprocess.run([cls.podman, 'run', '-d', '--network', 'none', '--name', cls.container,
                        '-v', str(config_path) + ':/tmp/test.cfg:ro,Z',
                        '--entrypoint', '/usr/sbin/kamailio', KAMAILIO_IMAGE,
                        '-DD', '-E', '-f', '/tmp/test.cfg'], check=True, capture_output=True)
        cls.addClassCleanup(subprocess.run, [cls.podman, 'rm', '-f', cls.container],
                            check=True, capture_output=True)

    def register(self, uri, direction):
        """Send a REGISTER and return the final status, status line, stored
        code and seconds waited."""
        result = subprocess.run([self.podman, 'run', '--rm', '-i', '--network', 'container:' + self.container,
                                 PYTHON_IMAGE, 'python3', '-c', CLIENT],
                                input=json.dumps([uri, direction, uuid.uuid4().hex]), text=True, capture_output=True, timeout=60)
        logs = subprocess.run([self.podman, 'logs', self.container], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr + logs.stderr)
        return json.loads(result.stdout)

    def test_unresolvable_destination_gets_503(self):
        status, line, stored, _ = self.register('sip:sip.unresolvable.invalid:5060', 'out')
        self.assertEqual(status, 503, line)
        self.assertEqual(stored, '408')

    def test_outbound_register_waits_for_the_provider(self):
        # Nothing listens on the port: no answer, tm replies 408 on timeout
        status, line, _, waited = self.register('sip:127.0.0.1:15099', 'out')
        self.assertEqual(status, 408, line)
        self.assertGreaterEqual(waited, 2.5)

    def test_inbound_register_keeps_the_short_timeout(self):
        status, line, _, waited = self.register('sip:127.0.0.1:15099', 'in')
        self.assertEqual(status, 408, line)
        self.assertLess(waited, 2.5)


if __name__ == '__main__':
    unittest.main()
