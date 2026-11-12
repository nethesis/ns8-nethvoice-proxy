#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "imageroot/pypkg"))

import sip_ports  # noqa: E402


class GetPortsTest(unittest.TestCase):
    def test_defaults_when_missing_or_empty(self):
        self.assertEqual(sip_ports.get_ports({}), (5060, 5061))
        self.assertEqual(sip_ports.get_ports({"SIP_PORT": "", "SIPS_PORT": ""}), (5060, 5061))

    def test_reads_the_environment(self):
        self.assertEqual(sip_ports.get_ports({"SIP_PORT": "5070", "SIPS_PORT": "5071"}), (5070, 5071))


class ValidatePortsTest(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(sip_ports.validate_ports(5060, 5061), [])
        self.assertEqual(sip_ports.validate_ports(5080, 5443), [])

    def test_same_port(self):
        self.assertEqual(sip_ports.validate_ports(5070, 5070), [("sips_port", "sip_ports_must_differ")])

    def test_local_listener_ports(self):
        self.assertEqual(sip_ports.validate_ports(6060, 5061), [("sip_port", "sip_port_reserved")])
        self.assertEqual(sip_ports.validate_ports(5060, 6061), [("sips_port", "sips_port_reserved")])


class PublicPortsTest(unittest.TestCase):
    def test_defaults_match_the_previous_fixed_list(self):
        self.assertEqual(sip_ports.public_ports(5060, 5061), ["5060-5061/tcp", "5060/udp", "10000-20000/udp"])
        self.assertEqual(
            sip_ports.public_ports(5060, 5061, True),
            ["5060-5061/tcp", "5060/udp", "10000-20000/udp", "6060-6061/tcp", "6060/udp"],
        )

    def test_ports_not_adjacent(self):
        self.assertEqual(sip_ports.public_ports(5080, 5443), ["5080/tcp", "5443/tcp", "5080/udp", "10000-20000/udp"])


class PortForwardRulesTest(unittest.TestCase):
    def test_default_rules_match_the_previous_ones(self):
        self.assertEqual(sip_ports.port_forward_rules(["192.168.1.0/24", ""], 5060, 5061), [
            "rule family=ipv4 source address=192.168.1.0/24 forward-port port=5060 protocol=udp to-port=6060",
            "rule family=ipv4 source address=192.168.1.0/24 forward-port port=5060 protocol=tcp to-port=6060",
            "rule family=ipv4 source address=192.168.1.0/24 forward-port port=5061 protocol=tcp to-port=6061",
        ])

    def test_custom_ports(self):
        rules = sip_ports.port_forward_rules(["10.0.0.0/8"], 5070, 5071)
        self.assertIn("rule family=ipv4 source address=10.0.0.0/8 forward-port port=5070 protocol=udp to-port=6060", rules)
        self.assertIn("rule family=ipv4 source address=10.0.0.0/8 forward-port port=5071 protocol=tcp to-port=6061", rules)


if __name__ == "__main__":
    unittest.main()
