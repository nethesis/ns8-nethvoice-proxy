#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import http.server
import io
import json
import os
import socket
import subprocess
import sys
import threading
import time
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "imageroot" / "pypkg"))

from proxymetrics import kamailio  # noqa: E402
from proxymetrics.runner import CheckUnavailable  # noqa: E402

# htable.dump answer of Kamailio 5.8.8 on rl1, keys set by hand
DUMP = json.loads((Path(__file__).parent / "fixtures" / "htable_dump_nvtrunkreg.json").read_text())


class ReadEntriesTest(unittest.TestCase):
    def test_slots_of_every_bucket(self):
        calls = []

        def rpc(method, params):
            calls.append((method, params))
            return DUMP["result"]

        self.assertEqual(
            kamailio.read_entries("nvtrunkreg", rpc), {"6|NvTestProxy@192.0.2.12": 403, "6|user@sip.example.com": 200}
        )
        self.assertEqual(calls, [("htable.dump", ["nvtrunkreg"])])

    def test_empty_table(self):
        self.assertEqual(kamailio.read_entries("nvtrunkopt", lambda method, params: []), {})


class RenderTest(unittest.TestCase):
    def render(self, entries, instances):
        err = io.StringIO()
        with redirect_stderr(err):
            text = kamailio.render(entries, instances)
        return text, err.getvalue()

    def test_registered_and_rejected(self):
        text, _ = self.render({"6|NvTestProxy@192.0.2.12": 403, "6|user@sip.example.com": 200}, {"6": "nethvoice2"})
        self.assertIn('nethvoice_proxy_trunk_registration_status_code{nethvoice="nethvoice2",trunk="user@sip.example.com"} 200\n', text)
        self.assertIn('nethvoice_proxy_trunk_registration_status_code{nethvoice="nethvoice2",trunk="NvTestProxy@192.0.2.12"} 403\n', text)

    def test_timeout(self):
        text, _ = self.render({"1|100@sip.provider.it": "408"}, {"1": "nethvoice1"})
        self.assertIn('nethvoice_proxy_trunk_registration_status_code{nethvoice="nethvoice1",trunk="100@sip.provider.it"} 408\n', text)

    def test_set_id_of_a_removed_instance_is_skipped(self):
        text, err = self.render({"9|100@sip.provider.it": 403, "1|200@sip.provider.it": 200}, {"1": "nethvoice1"})
        self.assertNotIn("100@sip.provider.it", text)
        self.assertNotIn("unknown", text)
        self.assertIn('nethvoice="nethvoice1",trunk="200@sip.provider.it"', text)
        self.assertEqual(err, "")

    def test_two_set_ids_of_the_same_instance_give_one_series(self):
        text, _ = self.render({"1|100@sip.provider.it": 200, "2|100@sip.provider.it": 200}, {"1": "nethvoice2", "2": "nethvoice2"})
        self.assertEqual(text.count("nethvoice_proxy_trunk_registration_status_code{"), 1)

    def test_malformed_entries_are_skipped(self):
        text, err = self.render({"garbage": 200, "1|100@sip.provider.it": "abc"}, {"1": "nethvoice1"})
        self.assertNotIn("nethvoice_proxy_trunk_registration_status_code{", text)
        self.assertIn("garbage", err)

    def test_label_values_are_escaped(self):
        text, _ = self.render({'1|a"b@sip.provider.it': 200}, {"1": "nethvoice1"})
        self.assertIn('trunk="a\\"b@sip.provider.it"', text)

    def test_ip_trunk_options(self):
        options = {"6|77.239.128.13:5060": 408, "6|198.51.100.7:5060": 404}
        text = kamailio.render({}, {"6": "nethvoice173"}, options)
        self.assertIn('nethvoice_proxy_trunk_options_status_code{nethvoice="nethvoice173",trunk="77.239.128.13:5060"} 408\n', text)
        # Any answer means the provider is alive: the code is exported as it is
        self.assertIn('nethvoice_proxy_trunk_options_status_code{nethvoice="nethvoice173",trunk="198.51.100.7:5060"} 404\n', text)
        self.assertNotIn("nethvoice_proxy_trunk_registration_status_code{", text)

    def test_collect_reads_both_tables(self):
        tables = []

        def entries(table):
            tables.append(table)
            return {"6|77.239.128.13:5060": 200} if table == "nvtrunkopt" else {}

        text = kamailio.collect(entries, lambda: {"6": "nethvoice173"})
        self.assertCountEqual(tables, ["nvtrunkreg", "nvtrunkopt"])
        self.assertIn('trunk_options_status_code{nethvoice="nethvoice173",trunk="77.239.128.13:5060"} 200\n', text)

    def test_collect_reads_in_parallel(self):
        def entries(table):
            time.sleep(0.5)
            return {}

        def instances():
            time.sleep(0.5)
            return {}

        started = time.monotonic()
        kamailio.collect(entries, instances)
        self.assertLess(time.monotonic() - started, 1.2)

    def test_collect_fails_when_a_read_fails(self):
        def instances():
            raise CheckUnavailable("postgres down")

        with self.assertRaises(CheckUnavailable):
            kamailio.collect(lambda table: {}, instances)

    def test_reserved_labels_are_never_set(self):
        text, _ = self.render({"6|user@sip.example.com": 200}, {"6": "nethvoice2"})
        self.assertNotRegex(text, r"(module|module_id|instance)=")


class ReadInstancesTest(unittest.TestCase):
    def test_dispatcher_rows(self):
        def run(args, **kwargs):
            self.assertEqual(args[:4], ["podman", "exec", "postgres", "sh"])
            return subprocess.CompletedProcess(args, 0, stdout="1|nethvoice2\n2|nethvoice2\n3|\n\n")

        self.assertEqual(kamailio.read_instances(run), {"1": "nethvoice2", "2": "nethvoice2"})


class RpcTest(unittest.TestCase):
    def serve(self, answer):
        received = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                received.append(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
                body = json.dumps(answer).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return "http://127.0.0.1:%d/RPC" % server.server_port, received

    def test_result_without_environment_proxy(self):
        url, received = self.serve(DUMP)
        # Nothing listens on the proxy port: the call fails if the proxy is used
        proxy = {"http_proxy": "http://127.0.0.1:9", "HTTP_PROXY": "http://127.0.0.1:9", "no_proxy": "", "NO_PROXY": ""}
        with mock.patch.dict(os.environ, proxy):
            self.assertEqual(kamailio.rpc("htable.dump", ["nvtrunkreg"], url), DUMP["result"])
        self.assertEqual(received[0]["method"], "htable.dump")
        self.assertEqual(received[0]["params"], ["nvtrunkreg"])

    def test_rpc_error_is_unavailable(self):
        url, _ = self.serve({"jsonrpc": "2.0", "error": {"code": 500, "message": "No such htable"}, "id": 1})
        with self.assertRaises(CheckUnavailable):
            kamailio.rpc("htable.dump", ["nvtrunkreg"], url)

    def test_kamailio_down_is_unavailable(self):
        sock = socket.socket()
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
        sock.close()
        with self.assertRaises(CheckUnavailable):
            kamailio.rpc("htable.dump", ["nvtrunkreg"], "http://127.0.0.1:%d/RPC" % port)


if __name__ == "__main__":
    unittest.main()
