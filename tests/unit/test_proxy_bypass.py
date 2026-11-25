#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "imageroot/pypkg"))

import proxy_bypass  # noqa: E402
import sip_ports  # noqa: E402

GATEWAY = {"address": "192.168.10.245", "module_id": "nethvoice1", "port": 20999}


class SourcesFormatTest(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(proxy_bypass.parse_sources(None), [])
        self.assertEqual(proxy_bypass.parse_sources(""), [])
        self.assertEqual(proxy_bypass.format_sources([]), "")

    def test_round_trip(self):
        sources = [GATEWAY, {"address": "10.0.0.7", "module_id": "nethvoice12", "port": 21000}]
        value = proxy_bypass.format_sources(sources)
        self.assertEqual(value, "192.168.10.245:nethvoice1:20999,10.0.0.7:nethvoice12:21000")
        self.assertEqual(proxy_bypass.parse_sources(value), sources)

    def test_malformed_items_are_skipped(self):
        self.assertEqual(
            proxy_bypass.parse_sources("192.168.10.245:nethvoice1:20999,broken,1.2.3.4:nethvoice1:port"),
            [GATEWAY],
        )


class RulesTest(unittest.TestCase):
    def test_redirect_and_accept_for_each_source(self):
        self.assertEqual(
            proxy_bypass.rules([GATEWAY], 5060),
            [
                "rule priority=-10 family=ipv4 source address=192.168.10.245 forward-port port=5060 protocol=udp to-port=20999",
                "rule priority=-10 family=ipv4 source address=192.168.10.245 port port=20999 protocol=udp accept",
            ],
        )

    def test_follows_the_sip_port_of_the_proxy(self):
        self.assertIn("forward-port port=5070 protocol=udp", proxy_bypass.rules([GATEWAY], 5070)[0])

    def test_no_sources(self):
        self.assertEqual(proxy_bypass.rules([], 5060), [])

    def test_matches_the_rule_listed_by_firewalld(self):
        listed = 'rule priority="-10" family="ipv4" source address="192.168.10.245" forward-port port="5060" protocol="udp" to-port="20999"'
        self.assertEqual(sip_ports.rule_key(proxy_bypass.rules([GATEWAY], 5060)[0]), sip_ports.rule_key(listed))

    def test_evaluated_before_the_local_networks_rules(self):
        # The rules of the local networks have no priority, so firewalld
        # evaluates them after the ones with a negative priority
        self.assertLess(proxy_bypass.RULE_PRIORITY, 0)
        for rule in sip_ports.port_forward_rules(["192.168.10.0/24"], 5060, 5061):
            self.assertNotIn("priority", rule)


class DestinationTest(unittest.TestCase):
    def test_redirect_matches_the_address_of_the_proxy(self):
        redirect, accept = proxy_bypass.rules([GATEWAY], 5060, "192.168.10.1")
        self.assertEqual(
            redirect,
            "rule priority=-10 family=ipv4 source address=192.168.10.245 destination address=192.168.10.1 "
            "forward-port port=5060 protocol=udp to-port=20999",
        )
        self.assertNotIn("destination", accept)

    def test_listen_address(self):
        self.assertEqual(proxy_bypass.listen_address({"PRIVATE_IP": "192.168.10.1", "PUBLIC_IP": "203.0.113.1"}), "192.168.10.1")
        self.assertEqual(proxy_bypass.listen_address({"PRIVATE_IP": "", "PUBLIC_IP": "203.0.113.1"}), "203.0.113.1")
        self.assertEqual(proxy_bypass.listen_address({}), "")


class FakeFirewall:
    """The rich rules of the node, listed with quoted values as firewalld
    does."""

    def __init__(self):
        self.rules = []
        self.fail_add = False

    @staticmethod
    def listed(rule):
        return " ".join(
            f'{token.split("=", 1)[0]}="{token.split("=", 1)[1]}"' if "=" in token and '"' not in token else token
            for token in rule.split()
        )

    def list_rich_rules(self, raise_on_error=False):
        return list(self.rules)

    def add_rich_rules(self, rules):
        if self.fail_add:
            return False
        for rule in rules:
            if self.listed(rule) not in self.rules:
                self.rules.append(self.listed(rule))
        return True

    def remove_rich_rules(self, rules):
        keys = {sip_ports.rule_key(rule) for rule in rules}
        self.rules = [rule for rule in self.rules if sip_ports.rule_key(rule) not in keys]
        return True


class ReconcileTest(unittest.TestCase):
    proxy = "192.168.10.1"

    def setUp(self):
        self.state_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.state_dir.cleanup)
        patcher = mock.patch.dict(os.environ, {"AGENT_STATE_DIR": self.state_dir.name}, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.firewall = FakeFirewall()

    def reconcile(self, sources, sip_port=5060, destination=None):
        proxy_bypass.reconcile(sources, sip_port, self.proxy if destination is None else destination, self.firewall)

    def keys(self, rules):
        return {sip_ports.rule_key(rule) for rule in rules}

    def assert_firewall(self, rules):
        self.assertEqual(self.keys(self.firewall.rules), self.keys(rules))

    def test_add_and_remove(self):
        self.reconcile([GATEWAY])
        self.assert_firewall(proxy_bypass.rules([GATEWAY], 5060, self.proxy))
        self.reconcile([])
        self.assert_firewall([])

    def test_other_rules_are_left_alone(self):
        other = 'rule family="ipv4" source address="192.168.10.0/24" forward-port port="5060" protocol="udp" to-port="6060"'
        self.firewall.rules.append(other)
        self.reconcile([GATEWAY])
        self.reconcile([])
        self.assertEqual(self.firewall.rules, [other])

    def test_rules_follow_the_sip_port_and_the_address_of_the_proxy(self):
        self.reconcile([GATEWAY])
        self.reconcile([GATEWAY], sip_port=5070, destination="192.168.20.1")
        self.assert_firewall(proxy_bypass.rules([GATEWAY], 5070, "192.168.20.1"))

    def test_clear_after_a_save_that_failed_later(self):
        # The rules are added, then a later step of the save fails: the
        # sources are not saved in the environment
        self.reconcile([GATEWAY])
        self.assertEqual(os.environ.get("BYPASS_SOURCES"), None)
        self.reconcile([])
        self.assert_firewall([])

    def test_clear_after_a_failed_firewall_change(self):
        self.firewall.fail_add = True
        with self.assertRaises(RuntimeError):
            self.reconcile([GATEWAY])
        # Some of the rules could be in the firewall
        self.firewall.fail_add = False
        self.firewall.add_rich_rules(proxy_bypass.rules([GATEWAY], 5060, self.proxy)[:1])
        self.reconcile([])
        self.assert_firewall([])

    def migrate_instance_port(self, old_port, new_port):
        """What the update of NethVoice does when its SIP port moves."""
        self.firewall.rules = [
            rule.replace(f'to-port="{old_port}"', f'to-port="{new_port}"') if "forward-port" in rule else rule
            for rule in self.firewall.rules
        ]

    def test_instance_port_migration(self):
        self.reconcile([GATEWAY])
        self.migrate_instance_port(20999, 21500)
        moved = dict(GATEWAY, port=21500)
        self.reconcile([moved])
        self.assert_firewall(proxy_bypass.rules([moved], 5060, self.proxy))

    def test_removal_right_after_an_instance_port_migration(self):
        self.reconcile([GATEWAY])
        self.migrate_instance_port(20999, 21500)
        self.reconcile([])
        self.assert_firewall([])

    def test_rules_of_the_first_builds_are_replaced(self):
        # No file of the applied rules: they come from the saved sources
        legacy = proxy_bypass.rules([GATEWAY], 5060)
        self.firewall.add_rich_rules(legacy)
        with mock.patch.dict(os.environ, {"BYPASS_SOURCES": proxy_bypass.format_sources([GATEWAY])}):
            self.reconcile([GATEWAY])
        self.assert_firewall(proxy_bypass.rules([GATEWAY], 5060, self.proxy))


class ValidateSourcesTest(unittest.TestCase):
    ports = {"nethvoice1": 20999}

    def source(self, address, module_id="nethvoice1"):
        return {"address": address, "module_id": module_id}

    def test_valid(self):
        sources = [self.source("192.168.10.245"), self.source("192.168.10.246")]
        self.assertEqual(proxy_bypass.validate_sources(sources, self.ports), [])

    def test_address_must_be_ipv4(self):
        for address in ("192.168.10", "192.168.10.0/24", "gateway.example.com", "2001:db8::1", ""):
            self.assertEqual(
                proxy_bypass.validate_sources([self.source(address)], self.ports),
                [(address, "bypass_source_address_not_valid")],
            )

    def test_duplicated_address(self):
        sources = [self.source("192.168.10.245"), self.source("192.168.10.245")]
        self.assertEqual(
            proxy_bypass.validate_sources(sources, self.ports),
            [("192.168.10.245", "bypass_source_duplicated")],
        )

    def test_instance_must_be_on_the_node(self):
        self.assertEqual(
            proxy_bypass.validate_sources([self.source("192.168.10.245", "nethvoice2")], self.ports),
            [("nethvoice2", "bypass_source_instance_not_found")],
        )

    def test_saved_source_of_a_missing_instance_is_accepted(self):
        saved = [{"address": "192.168.10.245", "module_id": "nethvoice2", "port": 21000}]
        source = self.source("192.168.10.245", "nethvoice2")
        self.assertEqual(proxy_bypass.validate_sources([source], self.ports, saved), [])
        # only for the same address
        other = self.source("192.168.10.246", "nethvoice2")
        self.assertEqual(
            proxy_bypass.validate_sources([other], self.ports, saved),
            [("nethvoice2", "bypass_source_instance_not_found")],
        )


class ResolveSourcesTest(unittest.TestCase):
    def test_takes_the_current_port_of_the_instance(self):
        # the saved port is replaced by the one the instance has now
        saved = {"address": "192.168.10.245", "module_id": "nethvoice1", "port": 20500}
        self.assertEqual(proxy_bypass.resolve_sources([saved], {"nethvoice1": 20999}), ([GATEWAY], []))

    def test_missing_instance(self):
        source = {"address": "192.168.10.245", "module_id": "nethvoice2"}
        self.assertEqual(proxy_bypass.resolve_sources([GATEWAY, source], {"nethvoice1": 20999}), ([GATEWAY], [source]))


if __name__ == "__main__":
    unittest.main()
