#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import contextlib
import fcntl
import importlib.machinery
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[2] / "imageroot/bin/reload-routing"
loader = importlib.machinery.SourceFileLoader("reload_routing", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
reload_routing = importlib.util.module_from_spec(spec)
loader.exec_module(reload_routing)


class ReloadRoutingTest(unittest.TestCase):
    def setUp(self):
        self.clock = 0
        self.stderr = io.StringIO()
        self.enterContext(contextlib.redirect_stderr(self.stderr))
        self.enterContext(mock.patch.object(reload_routing.time, "monotonic", lambda: self.clock))
        self.sleep = self.enterContext(mock.patch.object(reload_routing.time, "sleep", self.advance))
        self.run = self.enterContext(mock.patch.object(reload_routing.subprocess, "run"))
        self.run.return_value = self.reply()

    def advance(self, seconds):
        self.clock += seconds

    @staticmethod
    def reply(stdout="", stderr="", code=0):
        return subprocess.CompletedProcess([], code, stdout, stderr)

    def test_zero_exit_rpc_fault_is_retried(self):
        self.run.side_effect = [self.reply("error: 500 - Ongoing reload\n"), self.reply("Ok. Dispatcher successfully reloaded.\n")]
        reload_routing.reload_table("dispatcher.reload", 45)
        self.assertEqual(self.run.call_count, 2)
        self.assertEqual(self.clock, 5)
        self.assertIn("rate limited", self.stderr.getvalue())

    def test_permanent_rpc_fault_fails_even_with_zero_exit(self):
        self.run.return_value = self.reply("error: 500 - Reload Failed\n")
        with self.assertRaisesRegex(RuntimeError, "Reload Failed"):
            reload_routing.reload_table("dispatcher.reload", 45)
        self.run.assert_called_once()

    def test_transport_failure_fails(self):
        self.run.return_value = self.reply(stderr="cannot connect to control socket", code=1)
        with self.assertRaisesRegex(RuntimeError, "control socket"):
            reload_routing.reload_table("dispatcher.reload", 45)

    def test_repeated_rate_limit_is_bounded(self):
        self.run.return_value = self.reply("error: 500 - Ongoing reload\n")
        with self.assertRaisesRegex(RuntimeError, "Timed out"):
            reload_routing.reload_table("dispatcher.reload", 12)
        self.assertEqual(self.clock, 12)
        self.assertEqual(self.run.call_count, 3)

    def test_rpc_timeout_is_bounded_by_deadline(self):
        self.run.side_effect = subprocess.TimeoutExpired("kamcmd", 3)
        with self.assertRaises(subprocess.TimeoutExpired):
            reload_routing.reload_table("dispatcher.reload", 3)
        self.assertEqual(self.run.call_args.kwargs["timeout"], 3)

    def test_sequence_stops_after_first_failure(self):
        with tempfile.TemporaryDirectory() as state, mock.patch.dict(os.environ, AGENT_STATE_DIR=state):
            self.run.return_value = self.reply("error: 500 - Reload Failed")
            with self.assertRaises(RuntimeError):
                reload_routing.reload_routing(["domain.reload", "dialplan.reload", "dispatcher.reload"])
        self.assertEqual(self.run.call_count, 1)

    def test_locked_sequence_cannot_reload_and_has_bounded_wait(self):
        with tempfile.TemporaryDirectory() as state, mock.patch.dict(os.environ, AGENT_STATE_DIR=state):
            with open(Path(state) / "routing-reload.lock", "a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                with self.assertRaisesRegex(RuntimeError, "Timed out"):
                    reload_routing.reload_routing(["dispatcher.reload"])
        self.run.assert_not_called()

    def test_sequence_holds_lock_and_releases_it(self):
        with tempfile.TemporaryDirectory() as state, mock.patch.dict(os.environ, AGENT_STATE_DIR=state):
            def locked_rpc(*args, **kwargs):
                with open(Path(state) / "routing-reload.lock", "a") as other:
                    with self.assertRaises(BlockingIOError):
                        fcntl.flock(other, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return self.reply()
            self.run.side_effect = locked_rpc
            reload_routing.reload_routing(["dialplan.reload", "dispatcher.reload"])
            with open(Path(state) / "routing-reload.lock", "a") as other:
                fcntl.flock(other, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.assertEqual(self.run.call_count, 2)


if __name__ == "__main__":
    unittest.main()
