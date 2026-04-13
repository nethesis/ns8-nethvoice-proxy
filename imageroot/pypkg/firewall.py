#!/usr/bin/env python3

#
# Copyright (C) 2025 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import os


BASE_PUBLIC_PORTS = [
    "5060-5061/tcp",
    "5060/udp",
    "10000-20000/udp",
]

NAT_PUBLIC_PORTS = [
    "6060-6061/tcp",
    "6060/udp",
]

DEFAULT_TRUNK_PORT_START = 5071
SLOT_TLS_PORT_OFFSET = 1000


def create_port_forward_rules(local_networks_list):
    """Create NAT workaround rules for networks that cannot hairpin to the public IP."""
    rules = []
    for network in local_networks_list:
        if network:
            rules.append(f'rule family=ipv4 source address={network} forward-port port=5060 protocol=udp to-port=6060')
            rules.append(f'rule family=ipv4 source address={network} forward-port port=5060 protocol=tcp to-port=6060')
            rules.append(f'rule family=ipv4 source address={network} forward-port port=5061 protocol=tcp to-port=6061')
    return rules


def get_slot_public_ports(slot_count, start_port):
    """Return the firewall ports required for slot-based trunks."""
    if slot_count < 0:
        raise ValueError("TRUNK_SLOTS cannot be negative")
    if start_port < 1:
        raise ValueError("TRUNK_PORT_START must be greater than zero")

    if slot_count == 0:
        return []

    end_port = start_port + slot_count - 1
    tls_start_port = start_port + SLOT_TLS_PORT_OFFSET
    tls_end_port = end_port + SLOT_TLS_PORT_OFFSET
    if tls_end_port > 65535:
        raise ValueError("TRUNK_SLOTS and TRUNK_PORT_START exceed the valid slot listener range")

    port_range = str(start_port) if slot_count == 1 else f"{start_port}-{end_port}"
    tls_port_range = str(tls_start_port) if slot_count == 1 else f"{tls_start_port}-{tls_end_port}"
    return [
        f"{port_range}/tcp",
        f"{port_range}/udp",
        f"{tls_port_range}/tcp",
    ]


def get_slot_public_ports_from_env(env=None):
    env = env or os.environ
    slot_count = int(env.get("TRUNK_SLOTS", "0"))
    start_port = int(env.get("TRUNK_PORT_START", str(DEFAULT_TRUNK_PORT_START)))
    return get_slot_public_ports(slot_count, start_port)


def get_public_service_ports(behind_nat, env=None):
    ports = list(BASE_PUBLIC_PORTS)
    ports.extend(get_slot_public_ports_from_env(env))
    if behind_nat:
        ports.extend(NAT_PUBLIC_PORTS)
    return ports
