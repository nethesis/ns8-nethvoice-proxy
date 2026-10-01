#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

"""Run with: python3 -m unittest discover -s tests/integration -v

Requires Podman and the images below (override with the corresponding *_IMAGE
variables). Containers are disposable and have no external network access.
"""

import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[2]
POSTGRES_IMAGE = os.getenv('POSTGRES_IMAGE', 'docker.io/library/postgres:14.20-alpine')
KAMAILIO_IMAGE = os.getenv('KAMAILIO_IMAGE', 'ghcr.io/nethesis/nethvoice-proxy-kamailio:1.7.1')
PYTHON_IMAGE = os.getenv('PYTHON_IMAGE', 'docker.io/library/python:3.13.15-alpine')
STEPS = {'add-route': '20writeroute', 'get-route': '20readroute', 'remove-route': '20removeroute',
         'add-trunk': '20writetrunk'}
ADDRESS = [{'uri': 'sip:127.0.0.1:15080', 'description': 'module1'}]


class DomainRoutesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.podman = shutil.which('podman')
        if not cls.podman:
            raise unittest.SkipTest('Podman is required')
        cls.container = 'hostname-routes-' + uuid.uuid4().hex[:10]
        cls.directory = tempfile.TemporaryDirectory(prefix='hostname-routes-')
        cls.addClassCleanup(cls.directory.cleanup)
        subprocess.run([cls.podman, 'run', '-d', '--network', 'none', '--name', cls.container,
                        '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', '-e', 'POSTGRES_DB=kamailio',
                        POSTGRES_IMAGE], check=True, capture_output=True)
        cls.addClassCleanup(subprocess.run, [cls.podman, 'rm', '-f', '-v', cls.container],
                            check=True, capture_output=True)
        for _ in range(100):
            ready = subprocess.run([cls.podman, 'exec', cls.container, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'],
                                   capture_output=True)
            if ready.returncode == 0:
                break
            time.sleep(0.1)
        else:
            raise RuntimeError('PostgreSQL did not start')
        for migration in sorted((ROOT / 'modules/postgres/migrations').glob('*.sql')):
            cls.sql(migration.read_text())

        # Redirect only the production actions' database container, preserving
        # their actual psql invocation, transaction, output, and exit status.
        shim = Path(cls.directory.name) / 'podman'
        shim.write_text(f'''#!{sys.executable}
import os
import sys
args = sys.argv[1:]
if args[:3] != ['exec', '-i', 'postgres']:
    raise SystemExit('Unexpected podman command')
args[2] = {cls.container!r}
os.execv({cls.podman!r}, [{cls.podman!r}] + args)
''')
        shim.chmod(0o755)
        cls.env = dict(os.environ, POSTGRES_USER='postgres', POSTGRES_DB='kamailio',
                       PYTHONPATH=str(ROOT / 'imageroot/pypkg'),
                       PATH=cls.directory.name + os.pathsep + os.environ['PATH'])

    @classmethod
    def sql(cls, query):
        result = subprocess.run([cls.podman, 'exec', '-i', cls.container, 'psql', '-X', '-qAt',
                               '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', 'kamailio'],
                                input=query, text=True, capture_output=True)
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout.strip()

    def setUp(self):
        self.sql('TRUNCATE nethvoice_proxy_routes, domain, dialplan, dispatcher RESTART IDENTITY;')

    def action(self, name, domain='Voice.Example.org', address=None, check=True, **extra):
        data = dict(domain=domain, **extra)
        if name == 'add-route':
            data['address'] = ADDRESS if address is None else address
        result = subprocess.run([sys.executable, str(ROOT / 'imageroot/actions' / name / STEPS[name])],
                                input=json.dumps(data), text=True, capture_output=True, env=self.env)
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def snapshot(self):
        return {table: self.sql(f'SELECT coalesce(json_agg(t ORDER BY id), \'[]\'::json) FROM {table} t;')
                for table in ('nethvoice_proxy_routes', 'domain', 'dialplan', 'dispatcher')}

    def legacy_route(self):
        self.action('add-route')
        self.sql("""
UPDATE nethvoice_proxy_routes SET target = 'Voice.Example.org';
UPDATE domain SET domain = 'Voice.Example.org', did = 'Voice.Example.org';
UPDATE dialplan SET match_exp = 'Voice.Example.org';
""")
        return self.sql('SELECT setid FROM nethvoice_proxy_routes;')

    def assert_canonical(self, domain='voice.example.org'):
        self.assertEqual(self.sql('SELECT target FROM nethvoice_proxy_routes;'), domain)
        self.assertEqual(self.sql('SELECT domain || \'|\' || did FROM domain;'), domain + '|' + domain)
        self.assertEqual(self.sql('SELECT match_exp FROM dialplan;'), domain)

    def test_add_get_and_repeated_save_across_casing(self):
        setid = None
        for domain in ('Voice.Example.org', 'voice.example.org', 'VOICE.EXAMPLE.ORG'):
            self.action('add-route', domain)
            self.assert_canonical()
            current_setid = self.sql('SELECT setid FROM nethvoice_proxy_routes;')
            if setid is not None:
                self.assertEqual(current_setid, setid)
            setid = current_setid
            self.assertEqual(json.loads(self.action('get-route', domain).stdout), {'address': ADDRESS})

    def test_legacy_get_is_read_only_and_update_preserves_set(self):
        setid = self.legacy_route()
        before = self.snapshot()
        for domain in ('voice.example.org', 'VOICE.EXAMPLE.ORG', 'Voice.Example.org'):
            self.assertEqual(json.loads(self.action('get-route', domain).stdout), {'address': ADDRESS})
            self.assertEqual(self.snapshot(), before)
        addresses = [{'uri': 'sip:127.0.0.1:15081', 'description': "Alice's \\ phone"}]
        self.action('add-route', 'VOICE.EXAMPLE.ORG', addresses)
        self.assert_canonical()
        self.assertEqual(self.sql('SELECT setid FROM nethvoice_proxy_routes;'), setid)
        self.assertEqual(json.loads(self.action('get-route').stdout), {'address': addresses})

    def test_remove_legacy_route_preserves_unrelated_routes_and_trunks(self):
        self.legacy_route()
        self.action('add-route', 'other.example.org')
        self.action('add-trunk', rule='3906', destination=ADDRESS[0])
        self.action('remove-route', 'VOICE.EXAMPLE.ORG')
        self.assertEqual(json.loads(self.action('get-route').stdout), {})
        self.assertEqual(json.loads(self.action('get-route', 'other.example.org').stdout), {'address': ADDRESS})
        self.assertEqual(self.sql("SELECT count(*) FROM nethvoice_proxy_routes WHERE route_type = 'trunk';"), '1')
        self.assertEqual(self.sql('SELECT count(*) FROM dialplan WHERE dpid = 2;'), '1')
        self.assertEqual(self.sql("SELECT count(*) FROM domain WHERE lower(domain) = 'voice.example.org';"), '0')
        self.assertEqual(self.sql('SELECT count(*) FROM dispatcher;'), '2')

    def test_missing_route_is_empty_and_remove_is_idempotent(self):
        for _ in range(2):
            self.assertEqual(json.loads(self.action('get-route').stdout), {})
            self.action('remove-route')
        self.assertTrue(all(value == '[]' for value in self.snapshot().values()))

    def test_ambiguous_records_are_rejected_without_changes(self):
        duplicates = (
            "INSERT INTO nethvoice_proxy_routes (target, route_type) VALUES ('VOICE.EXAMPLE.ORG', 'domain');",
            "INSERT INTO domain (domain, did) VALUES ('VOICE.EXAMPLE.ORG', 'VOICE.EXAMPLE.ORG');",
            "INSERT INTO dialplan (dpid, pr, match_op, match_exp, match_len, subst_exp, repl_exp, attrs) SELECT dpid, pr, match_op, 'VOICE.EXAMPLE.ORG', match_len, subst_exp, repl_exp, attrs FROM dialplan;",
        )
        for duplicate in duplicates:
            with self.subTest(duplicate=duplicate):
                self.setUp()
                self.legacy_route()
                self.sql(duplicate)
                before = self.snapshot()
                for action in ('add-route', 'get-route', 'remove-route'):
                    result = self.action(action, check=False)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('Ambiguous SIP domain records', result.stderr)
                    self.assertEqual(result.stdout, '')
                    self.assertEqual(self.snapshot(), before)

    def test_conflicting_dialplan_backend_is_not_selected(self):
        self.legacy_route()
        self.sql("UPDATE dialplan SET repl_exp = '999', attrs = '999';")
        before = self.snapshot()
        for action in ('add-route', 'get-route', 'remove-route'):
            result = self.action(action, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Inconsistent SIP domain records', result.stderr)
            self.assertEqual(self.snapshot(), before)

    def test_failed_insert_or_update_rolls_back_all_tables(self):
        invalid = [{'uri': 'sip:127.0.0.1:15081', 'description': 'x' * 65}]
        for existing in (False, True):
            with self.subTest(existing=existing):
                if existing:
                    self.legacy_route()
                before = self.snapshot()
                result = self.action('add-route', address=invalid, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('value too long', result.stderr)
                self.assertEqual(self.snapshot(), before)

    def test_failed_remove_rolls_back_all_tables(self):
        self.legacy_route()
        self.sql("""
CREATE FUNCTION reject_route_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'injected delete failure'; END $$;
CREATE TRIGGER reject_route_delete BEFORE DELETE ON dispatcher
FOR EACH ROW EXECUTE FUNCTION reject_route_delete();
""")
        try:
            before = self.snapshot()
            result = self.action('remove-route', check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('injected delete failure', result.stderr)
            self.assertEqual(self.snapshot(), before)
        finally:
            self.sql('DROP TRIGGER reject_route_delete ON dispatcher; DROP FUNCTION reject_route_delete();')

    def test_concurrent_case_variants_create_one_route(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            list(executor.map(lambda domain: self.action('add-route', domain),
                              ['Voice.Example.org', 'voice.example.org', 'VOICE.EXAMPLE.ORG'] * 2))
        self.assert_canonical()
        self.assertEqual(self.sql('SELECT count(*) FROM dispatcher;'), '1')

    def test_sip_routes_canonical_legacy_and_trunk_without_rewriting_request(self):
        self.action('add-route')
        self.action('add-route', 'Legacy.Example.org', [{'uri': 'sip:127.0.0.1:15081', 'description': 'legacy'}])
        self.sql("""
UPDATE nethvoice_proxy_routes SET target = 'Legacy.Example.org' WHERE target = 'legacy.example.org';
UPDATE domain SET domain = 'Legacy.Example.org', did = 'Legacy.Example.org' WHERE domain = 'legacy.example.org';
UPDATE dialplan SET match_exp = 'Legacy.Example.org' WHERE match_exp = 'legacy.example.org';
""")
        self.action('add-trunk', rule='3906', destination={'uri': 'sip:127.0.0.1:15082', 'description': 'trunk'})
        source = (ROOT / 'modules/kamailio/config/kamailio.cfg').read_text()
        start = source.index('route[GET_ASTERISK_NODE] {')
        end = source.index('} # end route[GET_ASTERISK_NODE]', start) + 1
        config = '''#!KAMAILIO
log_stderror=yes
debug=1
children=1
listen=udp:127.0.0.1:15060
mpath="/usr/lib/x86_64-linux-gnu/kamailio/modules/"
loadmodule "pv.so"
loadmodule "xlog.so"
loadmodule "sl.so"
loadmodule "db_postgres.so"
loadmodule "dialplan.so"
loadmodule "dispatcher.so"
modparam("dialplan", "db_url", "postgres://postgres@127.0.0.1/kamailio")
modparam("dispatcher", "db_url", "postgres://postgres@127.0.0.1/kamailio")
modparam("pv", "shvset", "debug=i:0")
request_route {
    route(GET_ASTERISK_NODE);
    if ($du == $null) { sl_send_reply("404", "No route"); exit; }
    forward();
    exit;
}
'''
        config_path = Path(self.directory.name) / 'kamailio.cfg'
        config_path.write_text(config + source[start:end] + '\n')
        kamailio = self.container + '-sip'
        subprocess.run([self.podman, 'run', '-d', '--network', 'container:' + self.container,
                        '--name', kamailio, '-v', str(config_path) + ':/tmp/test.cfg:ro,Z',
                        '--entrypoint', '/usr/sbin/kamailio', KAMAILIO_IMAGE,
                        '-DD', '-E', '-f', '/tmp/test.cfg'], check=True, capture_output=True)
        self.addCleanup(subprocess.run, [self.podman, 'rm', '-f', kamailio], check=True, capture_output=True)
        # Send real SIP packets and observe them at the selected UDP backend.
        client = '''
import select
import socket
import time

backends = []
for port in (15080, 15081, 15082):
    backend = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    backend.bind(('127.0.0.1', port))
    backends.append(backend)
client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
client.bind(('127.0.0.1', 15090))
time.sleep(0.5)
cases = [('MixedUser', 'voice.example.org', 15080),
         ('MixedUser', 'Voice.Example.org', 15080),
         ('MixedUser', 'VOICE.EXAMPLE.ORG', 15080),
         ('MixedUser', 'Legacy.Example.org', 15081),
         ('39061234', 'provider.example.net', 15082)]
for number, (user, domain, expected_port) in enumerate(cases):
    uri = f'sip:{user}@{domain}'
    request = (f'REGISTER {uri} SIP/2.0\\r\\n'
               f'Via: SIP/2.0/UDP 127.0.0.1:15090;branch=z9hG4bK-case-{number}\\r\\n'
               f'From: <{uri}>;tag=case-{number}\\r\\nTo: <{uri}>\\r\\n'
               f'Call-ID: case-{number}\\r\\nCSeq: 1 REGISTER\\r\\n'
               'Max-Forwards: 70\\r\\nContent-Length: 0\\r\\n\\r\\n')
    client.sendto(request.encode(), ('127.0.0.1', 15060))
    ready, _, _ = select.select(backends, [], [], 3)
    assert len(ready) == 1, f'No unique backend for {uri}'
    assert ready[0].getsockname()[1] == expected_port, f'Wrong backend for {uri}'
    received = ready[0].recv(65535).decode()
    assert received.startswith(f'REGISTER {uri} SIP/2.0\\r\\n'), received
    assert f'From: <{uri}>' in received and f'To: <{uri}>' in received, received
print('5 SIP requests reached the expected backends with original URIs and identities')
'''
        result = subprocess.run([self.podman, 'run', '--rm', '-i', '--network', 'container:' + self.container,
                                 PYTHON_IMAGE, 'python3', '-'], input=client, text=True, capture_output=True,
                                timeout=25)
        logs = subprocess.run([self.podman, 'logs', kamailio], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr + logs.stderr)


if __name__ == '__main__':
    unittest.main()
