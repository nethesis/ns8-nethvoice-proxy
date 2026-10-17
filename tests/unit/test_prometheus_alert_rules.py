#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import contextlib
import importlib.machinery
import importlib.util
import io
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import types
import unittest
from unittest import mock

import yaml


ROOT = Path(__file__).resolve().parents[2]
ENVIRONMENT = {
    "NETHVOICE_PROXY_SYSTEMD_EXPORTER_PORT": "20137",
    "SYSTEMD_EXPORTER_PROMETHEUS_PATH": "/destination-telemetry",
}
IDENTITY = {"MODULE_ID": "nethvoice-proxy42", "AGENT_ID": "module/nethvoice-proxy42", "NODE_ID": "7"}
KEY = "module/nethvoice-proxy42/metrics_alert_rules"
CHANNEL = "module/nethvoice-proxy42/event/metrics-alert-rules-changed"


def load_script(name, path, agent):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(name, loader))
    with mock.patch.dict("sys.modules", {"agent": agent}):
        loader.exec_module(module)
    return module


class PublisherTests(unittest.TestCase):
    def setUp(self):
        self.agent = types.ModuleType("agent")
        self.agent.SD_ERR = "<3>"
        self.env = dict(ENVIRONMENT)
        self.previous = {}
        self.agent.read_envfile = mock.Mock(return_value=self.env)
        self.rdb = mock.MagicMock()
        self.rdb.hmget.side_effect = lambda key, fields: [self.previous.get(f) for f in fields]
        self.agent.redis_connect = mock.MagicMock()
        self.agent.redis_connect.return_value.__enter__.return_value = self.rdb
        self.publisher = load_script("alert_rules", ROOT / "imageroot/bin/prometheus-alert-rules", self.agent)
        patch = mock.patch.dict(os.environ, IDENTITY, clear=True)
        patch.start()
        self.addCleanup(patch.stop)

    def test_five_distinct_bilingual_rules_without_fqdn_configuration(self):
        documents = self.publisher.build_rule_sets(self.env)
        self.assertEqual(set(documents), {"systemd-exporter", "core-services"})
        expected = {
            "NethVoiceProxyKamailioDown": "kamailio.service",
            "NethVoiceProxyRTPengineDown": "rtpengine.service",
            "NethVoiceProxyPostgreSQLDown": "postgres.service",
            "NethVoiceProxyRedisDown": "redis.service",
            "NethVoiceProxySystemdExporterDown": "systemd-exporter.service",
        }
        rules = []
        for name, document in documents.items():
            groups = yaml.safe_load(document)["groups"]
            self.assertEqual(len(groups), 1)
            self.assertEqual(groups[0]["name"], f"nethvoice-proxy.{name}")
            rules.extend(groups[0]["rules"])
        self.assertEqual(len(rules), 5)
        self.assertEqual({r["alert"]: r["labels"]["service"] for r in rules}, expected)
        for rule in rules:
            unit = expected[rule["alert"]]
            self.assertEqual(rule["for"], "5m")
            self.assertEqual(rule["labels"], {"severity": "critical", "service": unit})
            self.assertEqual(set(rule["annotations"]), {
                "summary_en", "summary_it", "description_en", "description_it",
            })
            for language in ("en", "it"):
                self.assertTrue(rule["annotations"][f"summary_{language}"])
                description = rule["annotations"][f"description_{language}"]
                self.assertIn("{{ $labels.module_id }}", description)
                self.assertIn("{{ $labels.node }}", description)
            expression = 'up{target_type="systemd"} == 0' if unit == "systemd-exporter.service" else (
                '(up{target_type="systemd"} == 1) unless on(instance, module_id) '
                '(systemd_unit_state{target_type="systemd", '
                f'name="{unit}", state="active"}} == 1)'
            )
            self.assertEqual(rule["expr"], expression)
        self.assertEqual(documents, self.publisher.build_rule_sets(dict(reversed(list(self.env.items())))))

    def test_missing_or_empty_exporter_environment_does_not_publish(self):
        for key in ENVIRONMENT:
            for value in (None, ""):
                with self.subTest(key=key, value=value):
                    env = dict(self.env)
                    if value is None:
                        env.pop(key)
                    else:
                        env[key] = value
                    self.agent.read_envfile.return_value = env
                    self.publisher.publish_rules()
        self.rdb.pipeline.assert_not_called()

    def test_publication_uses_runtime_identity_and_one_privileged_transaction(self):
        self.env.update(MODULE_ID="source1", AGENT_ID="module/source1", NODE_ID="1")
        self.publisher.publish_rules()
        self.agent.read_envfile.assert_called_once_with("environment")
        self.agent.redis_connect.assert_called_once_with(privileged=True)
        self.rdb.hmget.assert_called_once_with(KEY, self.publisher.RULE_SETS)
        self.rdb.pipeline.assert_called_once_with(transaction=True)
        trx = self.rdb.pipeline.return_value
        self.assertEqual(trx.hset.call_args_list, [
            mock.call(KEY, name, value) for name, value in self.publisher.build_rule_sets(self.env).items()
        ])
        trx.hdel.assert_not_called()
        trx.publish.assert_called_once_with(CHANNEL, "{}")
        trx.execute.assert_called_once_with()
        self.assertEqual([call[0] for call in trx.method_calls][-2:], ["publish", "execute"])

    def test_missing_runtime_identity_fails_before_redis_access(self):
        for key in ("MODULE_ID", "AGENT_ID"):
            with self.subTest(key=key), mock.patch.dict(os.environ, {}, clear=True):
                os.environ.update({k: v for k, v in IDENTITY.items() if k != key})
                with self.assertRaises(KeyError):
                    self.publisher.publish_rules()
        self.agent.redis_connect.assert_not_called()

    def test_unchanged_string_and_byte_responses_do_not_write_or_notify(self):
        for as_bytes in (False, True):
            self.previous.update({name: value.encode() if as_bytes else value
                                  for name, value in self.publisher.build_rule_sets(self.env).items()})
            self.publisher.publish_rules()
        self.rdb.pipeline.assert_not_called()

    def test_outdated_field_is_replaced_without_changing_other_fields(self):
        self.previous.update(self.publisher.build_rule_sets(self.env))
        self.previous.update({"core-services": "old rules", "custom": "unrelated"})
        self.publisher.publish_rules()
        trx = self.rdb.pipeline.return_value
        trx.hset.assert_called_once_with(KEY, "core-services", self.publisher.build_rule_sets(self.env)["core-services"])
        trx.hdel.assert_not_called()
        trx.delete.assert_not_called()
        trx.publish.assert_called_once_with(CHANNEL, "{}")

    def test_removal_only_deletes_owned_fields_without_reading_environment(self):
        self.previous.update({"core-services": "old", "systemd-exporter": "old", "custom": "unrelated"})
        self.publisher.publish_rules(remove=True)
        trx = self.rdb.pipeline.return_value
        trx.hdel.assert_called_once_with(KEY, "core-services", "systemd-exporter")
        trx.hset.assert_not_called()
        trx.delete.assert_not_called()
        trx.publish.assert_called_once_with(CHANNEL, "{}")
        trx.execute.assert_called_once_with()
        self.agent.read_envfile.assert_not_called()

    def test_removing_absent_owned_fields_is_a_noop(self):
        self.previous["custom"] = "unrelated"
        self.publisher.publish_rules(remove=True)
        self.rdb.pipeline.assert_not_called()

    def test_lost_exporter_configuration_removes_obsolete_owned_rules(self):
        self.previous.update(self.publisher.build_rule_sets(self.env))
        self.env.clear()
        self.publisher.publish_rules()
        self.rdb.pipeline.return_value.hdel.assert_called_once_with(KEY, "core-services", "systemd-exporter")

    def test_redis_connect_read_and_transaction_failures_propagate(self):
        for failing in (self.agent.redis_connect, self.rdb.hmget, self.rdb.pipeline.return_value.execute):
            for remove in (False, True):
                with self.subTest(failing=failing, remove=remove):
                    self.previous["core-services"] = "old"
                    failing.side_effect = RuntimeError("Redis unavailable")
                    with self.assertRaisesRegex(RuntimeError, "Redis unavailable"):
                        self.publisher.publish_rules(remove=remove)
                    failing.side_effect = None
            self.rdb.hmget.side_effect = lambda key, fields: [self.previous.get(f) for f in fields]

    def test_cli_accepts_update_and_remove_and_rejects_invalid_commands(self):
        with mock.patch.object(self.publisher, "publish_rules") as publish:
            for command in ("update", "remove"):
                with mock.patch("sys.argv", ["prometheus-alert-rules", command]):
                    self.publisher.main()
                publish.assert_called_with(remove=command == "remove")
            publish.reset_mock()
            for args in ([], ["invalid"], ["update", "extra"]):
                with mock.patch("sys.argv", ["prometheus-alert-rules", *args]), contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as error:
                        self.publisher.main()
                    self.assertEqual(error.exception.code, 2)
            publish.assert_not_called()

    def test_target_refresh_uses_destination_node_port_path_and_identity(self):
        self.env.update(MODULE_ID="source1", NODE_ID="1")
        self.rdb.hget.return_value = "10.5.4.7"
        targets = load_script("targets", ROOT / "imageroot/bin/prometheus-targets", self.agent)
        targets.update_targets()
        self.rdb.hget.assert_called_once_with("node/7/vpn", "ip_address")
        key, field, value = self.rdb.pipeline.return_value.hset.call_args.args
        self.assertEqual((key, field), ("module/nethvoice-proxy42/metrics_targets", "systemd"))
        self.assertEqual(yaml.safe_load(value), [{
            "targets": ["10.5.4.7:20137"],
            "labels": {"module_id": "nethvoice-proxy42", "node": "7", "__metrics_path__": "/destination-telemetry"},
        }])

    def test_target_precondition_errors_report_missing_environment_and_node_address(self):
        targets = load_script("targets", ROOT / "imageroot/bin/prometheus-targets", self.agent)
        for key in ENVIRONMENT:
            with self.subTest(key=key), contextlib.redirect_stderr(io.StringIO()) as log:
                with self.assertRaises(SystemExit) as error:
                    targets._build_target_configs({k: v for k, v in ENVIRONMENT.items() if k != key}, "proxy42", 7, "10.5.4.7")
                self.assertEqual(error.exception.code, 2)
                self.assertIn(f"{key} is not set", log.getvalue())
        self.rdb.hget.return_value = None
        with contextlib.redirect_stderr(io.StringIO()) as log:
            with self.assertRaises(SystemExit) as error:
                targets._read_node_address(7)
            self.assertEqual(error.exception.code, 2)
            self.assertIn("VPN address for node 7 is not available", log.getvalue())


class LifecycleTests(unittest.TestCase):
    UPDATE_HOOKS = (
        "actions/create-module/20metrics_target",
        "actions/configure-module/97metrics_target",
        "actions/restore-module/99metrics",
        "actions/clone-module/99metrics",
    )

    def test_shell_hooks_order_and_failure_propagation(self):
        hooks = [(path, "update", ["prometheus-targets", "prometheus-alert-rules"]) for path in self.UPDATE_HOOKS]
        hooks.append(("actions/destroy-module/10metrics_target", "remove", ["prometheus-alert-rules", "prometheus-targets"]))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for helper in ("prometheus-targets", "prometheus-alert-rules"):
                path = root / helper
                path.write_text('#!/bin/sh\nname=${0##*/}\nprintf "%s %s\\n" "$name" "$*" >> "$CALLS"\n'
                                'if [ "$name" = "$FAIL_HELPER" ]; then exit 17; fi\n')
                path.chmod(0o755)
            for hook, command, helpers in hooks:
                for failure in ("", *helpers):
                    with self.subTest(hook=hook, failure=failure):
                        calls = root / "calls"
                        calls.write_text("")
                        result = subprocess.run(
                            [str(ROOT / "imageroot" / hook)], capture_output=True, text=True,
                            env=dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", CALLS=str(calls), FAIL_HELPER=failure),
                            timeout=5,
                        )
                        expected = helpers[:helpers.index(failure) + 1] if failure else helpers
                        self.assertEqual(calls.read_text().splitlines(), [f"{helper} {command}" for helper in expected])
                        self.assertEqual(result.returncode, 17 if failure else 0, result.stderr)
                        self.assertEqual(result.stdout, "")

    def test_upgrade_guards_order_and_failure_propagation(self):
        hook = ROOT / "imageroot/update-module.d/15metrics_target"
        for missing in (None, *ENVIRONMENT):
            for failure in (None, "prometheus-targets", "prometheus-alert-rules"):
                with self.subTest(missing=missing, failure=failure):
                    agent = types.ModuleType("agent")
                    agent.read_envfile = mock.Mock(return_value={k: v for k, v in ENVIRONMENT.items() if k != missing})
                    agent.run_helper = mock.Mock(side_effect=lambda name, command: subprocess.CompletedProcess(
                        [name, command], 17 if name == failure else 0,
                    ))
                    with mock.patch.dict("sys.modules", {"agent": agent}), contextlib.redirect_stderr(io.StringIO()):
                        if missing:
                            with self.assertRaises(SystemExit) as error:
                                runpy.run_path(str(hook))
                            self.assertEqual(error.exception.code, 0)
                            agent.run_helper.assert_not_called()
                        elif failure:
                            with self.assertRaises(subprocess.CalledProcessError):
                                runpy.run_path(str(hook))
                        else:
                            runpy.run_path(str(hook))
                    if not missing:
                        expected = [mock.call("prometheus-targets", "update")]
                        if failure != "prometheus-targets":
                            expected.append(mock.call("prometheus-alert-rules", "update"))
                        self.assertEqual(agent.run_helper.call_args_list, expected)


if __name__ == "__main__":
    unittest.main()
