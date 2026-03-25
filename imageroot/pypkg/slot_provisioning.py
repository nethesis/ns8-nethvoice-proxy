#!/usr/bin/env python3

#
# Copyright (C) 2025 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import os
import time

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
    now = int(time.time())

    for assignment in psql_json(
        """
        SELECT COALESCE(
            json_agg(
                json_build_object(
                    'key_name', slot_assignments.key_name,
                    'slot', slot_assignments.key_value,
                    'expires', slot_assignments.expires
                )
                ORDER BY slot_assignments.key_name
            ),
            '[]'::json
        )
        FROM slot_assignments;
        """
    ) or []:
        expires = int(assignment.get("expires") or 0)
        if expires <= 0:
            continue

        ttl = expires - now if expires > now else expires
        if ttl <= 0:
            continue

        assignments.append({
            "key_name": assignment["key_name"],
            "slot": assignment["slot"],
            "ttl": ttl,
        })

    return assignments
