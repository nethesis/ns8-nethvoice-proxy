#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

"""Run with: python3 -m unittest discover -s tests/integration -v

Requires Podman and the images below (override with the corresponding *_IMAGE
variables). Containers are disposable and have no external network access.
"""

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

# The request route sets $du from an X-Du header, as loose_route() does from
# a Record-Route, runs route[DLGURI] and answers with the resulting $ru and $du.
CONFIG = '''#!KAMAILIO
#!define WITH_NAT
log_stderror=yes
debug=1
children=1
listen=udp:127.0.0.1:15060
mpath="/usr/lib/x86_64-linux-gnu/kamailio/modules/"
loadmodule "kex.so"
loadmodule "pv.so"
loadmodule "xlog.so"
loadmodule "sl.so"
loadmodule "textops.so"
loadmodule "siputils.so"
loadmodule "nathelper.so"
request_route {
    if (is_present_hf("X-Du")) {
        $du = $hdr(X-Du);
    }
    route(DLGURI);
    append_to_reply("X-Ru: $ru\\r\\nX-Du: $du\\r\\n");
    sl_send_reply("200", "OK");
    exit;
}
'''

CLIENT = '''
import json
import socket
import sys

client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
client.bind(('127.0.0.1', 15090))
client.settimeout(3)
results = []
for number, (uri, du) in enumerate(json.load(sys.stdin)):
    request = (f'BYE {uri} SIP/2.0\\r\\n'
               f'Via: SIP/2.0/UDP 127.0.0.1:15090;branch=z9hG4bK-dlguri-{number}\\r\\n'
               f'From: <sip:a@example.org>;tag=a{number}\\r\\nTo: <sip:b@example.org>;tag=b{number}\\r\\n'
               f'Call-ID: dlguri-{number}\\r\\nCSeq: 2 BYE\\r\\n'
               + (f'X-Du: {du}\\r\\n' if du else '') +
               'Max-Forwards: 70\\r\\nContent-Length: 0\\r\\n\\r\\n')
    client.sendto(request.encode(), ('127.0.0.1', 15060))
    reply = client.recv(65535).decode()
    headers = dict(line.split(': ', 1) for line in reply.split('\\r\\n')[1:] if ': ' in line)
    results.append([headers['X-Ru'], headers['X-Du']])
print(json.dumps(results))
'''


class DlgUriTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.podman = shutil.which('podman')
        if not cls.podman:
            raise unittest.SkipTest('Podman is required')
        cls.directory = tempfile.TemporaryDirectory(prefix='dlguri-')
        cls.addClassCleanup(cls.directory.cleanup)
        source = (ROOT / 'modules/kamailio/config/kamailio.cfg').read_text()
        start = source.index('route[DLGURI] {')
        end = source.index('} # end route[DLGURI]', start) + 1
        config_path = Path(cls.directory.name) / 'kamailio.cfg'
        config_path.write_text(CONFIG + source[start:end] + '\n')
        cls.container = 'dlguri-' + uuid.uuid4().hex[:10]
        subprocess.run([cls.podman, 'run', '-d', '--network', 'none', '--name', cls.container,
                        '-v', str(config_path) + ':/tmp/test.cfg:ro,Z',
                        '--entrypoint', '/usr/sbin/kamailio', KAMAILIO_IMAGE,
                        '-DD', '-E', '-f', '/tmp/test.cfg'], check=True, capture_output=True)
        cls.addClassCleanup(subprocess.run, [cls.podman, 'rm', '-f', cls.container],
                            check=True, capture_output=True)

    def dlguri(self, *requests):
        """Send in-dialog requests as (Request-URI, $du or None) and return
        the resulting [$ru, $du] of each one."""
        import json
        result = subprocess.run([self.podman, 'run', '--rm', '-i', '--network', 'container:' + self.container,
                                 PYTHON_IMAGE, 'python3', '-c', CLIENT],
                                input=json.dumps(requests), text=True, capture_output=True, timeout=25)
        logs = subprocess.run([self.podman, 'logs', self.container], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr + logs.stderr)
        return json.loads(result.stdout)

    def test_alias_without_route_set_becomes_the_destination(self):
        [(ru, du)] = self.dlguri(('sip:100@10.0.0.1:5060;alias=192.0.2.10~5070~1', None))
        self.assertEqual(ru, 'sip:100@10.0.0.1:5060')
        self.assertEqual(du, 'sip:192.0.2.10:5070')

    def test_alias_with_route_set_is_removed_and_the_next_hop_kept(self):
        [(ru, du)] = self.dlguri(('sip:100@10.0.0.1:5060;alias=192.0.2.10~5070~1', 'sip:203.0.113.5:5060;lr'))
        self.assertEqual(ru, 'sip:100@10.0.0.1:5060')
        self.assertEqual(du, 'sip:203.0.113.5:5060;lr')

    def test_malformed_alias_with_route_set_is_removed(self):
        [(ru, du)] = self.dlguri(('sip:100@10.0.0.1:5060;alias=garbage', 'sip:203.0.113.5:5060;lr'))
        self.assertEqual(ru, 'sip:100@10.0.0.1:5060')
        self.assertEqual(du, 'sip:203.0.113.5:5060;lr')

    def test_request_without_alias_is_unchanged(self):
        [(ru, du)] = self.dlguri(('sip:100@10.0.0.1:5060;transport=udp', 'sip:203.0.113.5:5060;lr'))
        self.assertEqual(ru, 'sip:100@10.0.0.1:5060;transport=udp')
        self.assertEqual(du, 'sip:203.0.113.5:5060;lr')


if __name__ == '__main__':
    unittest.main()
