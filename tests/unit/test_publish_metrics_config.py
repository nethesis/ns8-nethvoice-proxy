#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import importlib.machinery
import importlib.util
import sys
import tempfile
import types
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[2]
    / "imageroot"
    / "bin"
    / "publish-metrics-config"
)
KEY = "module/nethvoice-proxy1/metrics_alert_rules"
EVENT = "module/nethvoice-proxy1/event/metrics-alert-rules-changed"


def load_script():
    sys.modules["agent"] = types.ModuleType("agent")
    loader = importlib.machinery.SourceFileLoader("publish_metrics_config", str(SCRIPT_PATH))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class FakePipeline:
    def __init__(self, redis):
        self.redis = redis
        self.queued = []

    def hset(self, key, field, value):
        self.queued.append(("hset", key, field, value))

    def hdel(self, key, field):
        self.queued.append(("hdel", key, field))

    def publish(self, channel, message):
        self.queued.append(("publish", channel, message))

    def execute(self):
        for command in self.queued:
            self.redis.commands.append(command)
            if command[0] == "hset":
                self.redis.hashes.setdefault(command[1], {})[command[2]] = command[3]
            elif command[0] == "hdel":
                self.redis.hashes.get(command[1], {}).pop(command[2], None)


class FakeRedis:
    def __init__(self, hashes=None):
        self.hashes = hashes or {}
        self.commands = []

    def hgetall(self, key):
        return dict(self.hashes.get(key, {}))

    def pipeline(self):
        return FakePipeline(self)

    def events(self):
        return [c for c in self.commands if c[0] == "publish"]


class PublishTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = load_script()

    def publish(self, redis, rules):
        return self.script.publish(redis, "nethvoice-proxy1", "module/nethvoice-proxy1", rules)

    def test_first_publish_writes_and_emits_once(self):
        redis = FakeRedis()
        self.assertTrue(self.publish(redis, {"proxy-services": "groups: []\n"}))
        self.assertEqual(redis.hashes[KEY], {"proxy-services": "groups: []\n"})
        self.assertEqual(redis.events(), [("publish", EVENT, "{}")])

    def test_second_publish_is_noop(self):
        redis = FakeRedis({KEY: {"proxy-services": "groups: []\n"}})
        self.assertFalse(self.publish(redis, {"proxy-services": "groups: []\n"}))
        self.assertEqual(redis.commands, [])

    def test_rule_file_change_updates_field(self):
        redis = FakeRedis({KEY: {"proxy-services": "old\n"}})
        self.assertTrue(self.publish(redis, {"proxy-services": "new\n"}))
        self.assertEqual(redis.hashes[KEY]["proxy-services"], "new\n")
        self.assertEqual(len(redis.events()), 1)

    def test_removed_rule_file_deletes_owned_field(self):
        redis = FakeRedis({KEY: {"proxy-services": "x\n", "proxy-old": "y\n"}})
        self.assertTrue(self.publish(redis, {"proxy-services": "x\n"}))
        self.assertEqual(redis.hashes[KEY], {"proxy-services": "x\n"})
        self.assertEqual(len(redis.events()), 1)

    def test_foreign_fields_untouched(self):
        redis = FakeRedis({KEY: {"custom": "z\n", "nethvoice-services": "w\n"}})
        self.publish(redis, {"proxy-services": "x\n"})
        self.assertEqual(redis.hashes[KEY]["custom"], "z\n")
        self.assertEqual(redis.hashes[KEY]["nethvoice-services"], "w\n")

    def test_disabled_alerts_remove_owned_fields_only(self):
        redis = FakeRedis({KEY: {"custom": "z\n", "proxy-services": "x\n", "proxy-telephony": "y\n"}})
        self.assertTrue(self.publish(redis, {}))
        self.assertEqual(redis.hashes[KEY], {"custom": "z\n"})
        self.assertEqual(redis.events(), [("publish", EVENT, "{}")])

    def test_disabled_alerts_without_rules_is_noop(self):
        redis = FakeRedis({KEY: {"custom": "z\n"}})
        self.assertFalse(self.publish(redis, {}))
        self.assertEqual(redis.commands, [])

    def test_foreign_field_alone_is_noop(self):
        redis = FakeRedis({KEY: {"custom": "z\n", "proxy-services": "x\n"}})
        self.assertFalse(self.publish(redis, {"proxy-services": "x\n"}))
        self.assertEqual(redis.commands, [])


class DesiredRulesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = load_script()

    def test_one_field_per_owned_yml_file(self):
        with tempfile.TemporaryDirectory() as rules_dir:
            Path(rules_dir, "proxy-services.yml").write_text("a\n")
            Path(rules_dir, "README").write_text("b\n")
            Path(rules_dir, "other.yml").write_text("c\n")
            self.assertEqual(self.script.desired_rules(rules_dir), {"proxy-services": "a\n"})

    def test_shipped_rules(self):
        self.assertIn("proxy-services", self.script.desired_rules())


class WantedRulesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = load_script()

    def test_enabled_publishes_shipped_rules(self):
        rules = self.script.wanted_rules({"ALERTS_ENABLED": "true"})
        self.assertEqual(rules, self.script.desired_rules())
        self.assertIn("proxy-telephony", rules)

    def test_disabled_publishes_nothing(self):
        self.assertEqual(self.script.wanted_rules({"ALERTS_ENABLED": "false"}), {})

    def test_missing_flag_means_disabled(self):
        self.assertEqual(self.script.wanted_rules({}), {})


if __name__ == "__main__":
    unittest.main()
