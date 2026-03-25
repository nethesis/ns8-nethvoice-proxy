#!/usr/bin/env python3

#
# Copyright (C) 2025 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import os
import re

import utils


def psql_json(query, variables=None):
    return utils.psql_json(query, variables=variables)


def psql_exec(query, variables=None):
    return utils.psql_exec(query, variables=variables)


def kamcmd(*arguments):
    return utils.kamcmd(*arguments)


def kamcmd_output(*arguments):
    return utils.kamcmd_output(*arguments)


def reload_htable(table_name):
    utils.kamcmd('htable.reload', table_name)


def default_slot_count():
    return int(os.environ.get('TRUNK_SLOTS', '0'))


def default_slot_port_start():
    return int(os.environ.get('TRUNK_PORT_START', '5071'))


def slot_number(slot_name):
    return int(slot_name.removeprefix('slot'))


def slot_port(slot_name, port_start=None):
    base_port = default_slot_port_start() if port_start is None else port_start
    return base_port + slot_number(slot_name) - 1


def slot_tls_port(slot_name, port_start=None):
    return slot_port(slot_name, port_start) + 1000


def slot_port_ranges(slot_count=None, port_start=None):
    count = default_slot_count() if slot_count is None else slot_count
    start = default_slot_port_start() if port_start is None else port_start
    if count <= 0:
        return {
            "slot_count": 0,
            "udp_tcp_port_start": 0,
            "udp_tcp_port_end": 0,
            "tls_port_start": 0,
            "tls_port_end": 0,
        }

    return {
        "slot_count": count,
        "udp_tcp_port_start": start,
        "udp_tcp_port_end": start + count - 1,
        "tls_port_start": start + 1000,
        "tls_port_end": start + 1000 + count - 1,
    }


def public_service_ports(slot_count=None, port_start=None):
    ranges = slot_port_ranges(slot_count=slot_count, port_start=port_start)
    ports = [
        "5060-5061/tcp",
        "5060-5061/udp",
        "6060-6061/tcp",
        "6060-6061/udp",
        "10000-20000/udp",
    ]
    if ranges["slot_count"] > 0:
        ports.extend([
            f'{ranges["udp_tcp_port_start"]}-{ranges["udp_tcp_port_end"]}/tcp',
            f'{ranges["udp_tcp_port_start"]}-{ranges["udp_tcp_port_end"]}/udp',
            f'{ranges["tls_port_start"]}-{ranges["tls_port_end"]}/tcp',
        ])
    return ports


def split_slot_key(key_name):
    if "::" not in key_name:
        return key_name, ""
    return key_name.split("::", 1)


def live_slot_assignments():
    assignments = []
    current = {}

    for raw_line in utils.kamcmd_output('htable.dump', 'slotassign').splitlines():
        line = raw_line.strip()
        if not line:
            continue

        name_match = re.search(r'\b(?:name|key)\s*[:=]\s*([^\s,}]+)', line)
        value_match = re.search(r'\bvalue\s*[:=]\s*([^\s,}]+)', line)
        ttl_match = re.search(r'\bexpires?\s*[:=]\s*([0-9]+)', line)

        if name_match and current.get("key_name") and current.get("slot"):
            assignments.append(current)
            current = {}

        if name_match:
            current["key_name"] = name_match.group(1).strip('"')
        if value_match:
            current["slot"] = value_match.group(1).strip('"')
        if ttl_match:
            current["ttl"] = int(ttl_match.group(1))

        if line == "}" and current.get("key_name") and current.get("slot"):
            assignments.append(current)
            current = {}

    if current.get("key_name") and current.get("slot"):
        assignments.append(current)

    return assignments
