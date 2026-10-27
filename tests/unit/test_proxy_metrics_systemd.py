#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "imageroot" / "pypkg"))

from proxymetrics import systemd  # noqa: E402


def unit(name, active, file_state="enabled", restarts="0", inactive_exit="1000", load="loaded", wanted_by=""):
    return (
        f"Id={name}.service\n"
        f"LoadState={load}\n"
        f"ActiveState={active}\n"
        f"UnitFileState={file_state}\n"
        f"NRestarts={restarts}\n"
        f"InactiveExitTimestampMonotonic={inactive_exit}\n"
        f"WantedBy={wanted_by}\n"
    )


def show_output(*units):
    return "\n".join(units)


class ParseShowTest(unittest.TestCase):
    def test_blocks_are_split_on_empty_lines(self):
        units = systemd.parse_show(show_output(unit("kamailio", "active"), unit("rtpengine", "failed")))
        self.assertEqual([u["Id"] for u in units], ["kamailio.service", "rtpengine.service"])
        self.assertEqual(units[1]["ActiveState"], "failed")

    def test_value_containing_equal_sign_is_kept(self):
        units = systemd.parse_show("Id=a.service\nDescription=x=y\n")
        self.assertEqual(units[0]["Description"], "x=y")


class ServiceUpTest(unittest.TestCase):
    def up(self, text, running=()):
        return systemd.service_up(systemd.parse_show(text)[0], running)

    def test_running_or_restarting_is_up(self):
        for state in ("active", "reloading", "activating"):
            self.assertEqual(self.up(unit("kamailio", state)), 1, state)

    def test_enabled_failed_is_down(self):
        self.assertEqual(self.up(unit("kamailio", "failed")), 0)

    def test_static_failed_wanted_by_running_unit_is_down(self):
        # rtpengine has no [Install] section: kamailio pulls it in
        text = unit("rtpengine", "failed", file_state="static", wanted_by="kamailio.service")
        self.assertEqual(self.up(text, running={"kamailio.service"}), 0)

    def test_static_failed_wanted_by_stopped_unit_is_not_exported(self):
        # kamailio stopped on purpose: rtpengine stays failed until reset-failed
        text = unit("rtpengine", "failed", file_state="static", wanted_by="kamailio.service")
        self.assertIsNone(self.up(text, running={"postgres.service"}))

    def test_enabled_unit_stopped_after_running_is_down(self):
        self.assertEqual(self.up(unit("kamailio", "inactive")), 0)

    def test_enabled_unit_never_started_is_not_exported(self):
        self.assertIsNone(self.up(unit("kamailio", "inactive", inactive_exit="0")))

    def test_disabled_stopped_unit_is_not_exported(self):
        self.assertIsNone(self.up(unit("kamailio", "inactive", file_state="disabled")))

    def test_static_stopped_unit_is_not_exported(self):
        self.assertIsNone(self.up(unit("rtpengine", "inactive", file_state="static")))

    def test_static_stopped_unit_wanted_by_stopped_unit_is_not_exported(self):
        text = unit("rtpengine", "inactive", file_state="static", wanted_by="kamailio.service")
        self.assertIsNone(self.up(text, running={"postgres.service"}))

    def test_static_stopped_unit_wanted_by_running_unit_is_down(self):
        for inactive_exit in ("1000", "0"):
            text = unit("rtpengine", "inactive", file_state="static", inactive_exit=inactive_exit, wanted_by="kamailio.service")
            self.assertEqual(self.up(text, running={"kamailio.service"}), 0, inactive_exit)


class RenderTest(unittest.TestCase):
    def render(self, *units):
        return systemd.render(systemd.parse_show(show_output(*units)))

    def test_samples(self):
        text = self.render(
            unit("kamailio", "active", restarts="2"),
            unit("rtpengine", "failed", file_state="static", restarts="5", wanted_by="kamailio.service"),
        )
        self.assertIn('nethvoice_proxy_service_up{service="kamailio"} 1\n', text)
        self.assertIn('nethvoice_proxy_service_up{service="rtpengine"} 0\n', text)
        self.assertIn('nethvoice_proxy_service_restarts_total{service="kamailio"} 2\n', text)
        self.assertIn('nethvoice_proxy_service_restarts_total{service="rtpengine"} 5\n', text)
        self.assertIn("# TYPE nethvoice_proxy_service_up gauge\n", text)
        self.assertIn("# TYPE nethvoice_proxy_service_restarts_total counter\n", text)

    def test_static_stopped_unit_exports_only_restarts(self):
        text = self.render(unit("rtpengine", "inactive", file_state="static"))
        self.assertNotIn('nethvoice_proxy_service_up{service="rtpengine"}', text)
        self.assertIn('nethvoice_proxy_service_restarts_total{service="rtpengine"} 0\n', text)

    def test_static_unit_stopped_under_running_kamailio_is_down(self):
        text = self.render(
            unit("kamailio", "active"),
            unit("redis", "inactive", file_state="static", wanted_by="kamailio.service"),
            unit("rtpengine", "inactive", file_state="static", wanted_by="kamailio.service"),
        )
        self.assertIn('nethvoice_proxy_service_up{service="redis"} 0\n', text)
        self.assertIn('nethvoice_proxy_service_up{service="rtpengine"} 0\n', text)

    def test_static_units_stopped_with_kamailio_are_not_exported(self):
        text = self.render(
            unit("kamailio", "inactive", file_state="disabled"),
            unit("rtpengine", "inactive", file_state="static", wanted_by="kamailio.service"),
        )
        self.assertNotIn("nethvoice_proxy_service_up{", text)

    def test_static_unit_failed_before_kamailio_stopped_is_not_exported(self):
        text = self.render(
            unit("kamailio", "inactive"),
            unit("postgres", "inactive"),
            unit("rtpengine", "failed", file_state="static", restarts="3", wanted_by="kamailio.service"),
        )
        self.assertNotIn('nethvoice_proxy_service_up{service="rtpengine"}', text)
        self.assertIn('nethvoice_proxy_service_restarts_total{service="rtpengine"} 3\n', text)

    def test_unit_not_loaded_is_skipped(self):
        text = self.render(unit("rtpengine", "inactive", load="not-found"))
        self.assertNotIn('service="rtpengine"', text)

    def test_reserved_labels_are_never_set(self):
        text = self.render(unit("kamailio", "active"))
        self.assertNotRegex(text, r"(module|module_id|instance)=")


class ReadUnitsTest(unittest.TestCase):
    def test_one_systemctl_call_for_every_service(self):
        run = mock.Mock(return_value=subprocess.CompletedProcess([], 0, stdout=unit("kamailio", "active")))
        units = systemd.read_units(("kamailio", "rtpengine"), run=run)
        args = run.call_args.args[0]
        self.assertEqual(args[:3], ["systemctl", "--user", "show"])
        self.assertEqual(args[-2:], ["kamailio.service", "rtpengine.service"])
        self.assertEqual(run.call_args.kwargs["timeout"], systemd.TIMEOUT)
        self.assertEqual(units[0]["Id"], "kamailio.service")

    def test_watched_services(self):
        self.assertEqual(set(systemd.SERVICES), {"kamailio", "postgres", "redis", "rtpengine"})


if __name__ == "__main__":
    unittest.main()
