#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import sys
import unittest
from pathlib import Path

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
