#!/usr/bin/env python3

#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Proxy bypass: the SIP traffic over UDP of some source addresses, such as a
# local gateway, is redirected to the SIP port of a NethVoice instance of the
# same node and never reaches Kamailio.

import ipaddress
import os

# A rich rule with a negative priority is evaluated before the ones without
# priority, such as the redirect rules of the local networks: the bypass wins
# even when the source address belongs to a local network.
RULE_PRIORITY = -10


def parse_sources(value):
    """Return the bypass sources saved in the BYPASS_SOURCES variable, a
    comma-separated list of address:module_id:port items. The port is the one
    the firewall rule was created with."""
    sources = []
    for item in (value or "").split(","):
        fields = item.split(":")
        if len(fields) != 3 or not fields[2].isdigit():
            continue
        sources.append({"address": fields[0], "module_id": fields[1], "port": int(fields[2])})
    return sources


def format_sources(sources):
    """Return the value of the BYPASS_SOURCES variable."""
    return ",".join(f'{source["address"]}:{source["module_id"]}:{source["port"]}' for source in sources)


def rules(sources, sip_port):
    """Rich rules of the bypass sources. The first one redirects the SIP
    traffic over UDP to the NethVoice instance. The second one opens the SIP
    port of the instance: Asterisk writes it in its Contact header, so the
    source sends there the requests that follow the first one, such as ACK
    and BYE."""
    result = []
    for source in sources:
        match = f'rule priority={RULE_PRIORITY} family=ipv4 source address={source["address"]}'
        result.append(f'{match} forward-port port={sip_port} protocol=udp to-port={source["port"]}')
        result.append(f'{match} port port={source["port"]} protocol=udp accept')
    return result


def validate_sources(sources, instance_ports, saved_sources=()):
    """Return a list of (value, error) for the invalid bypass sources.
    instance_ports maps the NethVoice instances of the node to their SIP
    port. An instance that is gone is accepted for a source already saved,
    so that the saved configuration can always be applied again."""
    errors = []
    seen = set()
    saved = {(source["address"], source["module_id"]) for source in saved_sources}
    for source in sources:
        address = source["address"]
        try:
            ipaddress.IPv4Address(address)
        except ValueError:
            errors.append((address, "bypass_source_address_not_valid"))
            continue
        if address in seen:
            errors.append((address, "bypass_source_duplicated"))
            continue
        seen.add(address)
        module_id = source["module_id"]
        if module_id not in instance_ports and (address, module_id) not in saved:
            errors.append((module_id, "bypass_source_instance_not_found"))
    return errors


def resolve_sources(sources, instance_ports):
    """Return (resolved, missing): the sources with the SIP port of their
    NethVoice instance, and the ones whose instance is not on the node."""
    resolved = []
    missing = []
    for source in sources:
        port = instance_ports.get(source["module_id"])
        if port is None:
            missing.append(source)
        else:
            resolved.append({"address": source["address"], "module_id": source["module_id"], "port": port})
    return resolved, missing


def local_instance_ports():
    """Return the SIP port over UDP of the NethVoice instances of this node,
    by module ID."""
    import agent

    rdb = agent.redis_connect(use_replica=True)
    providers = agent.list_service_providers(rdb, "sip", "udp", {"node_id": os.environ["NODE_ID"]})
    return {provider["module_id"]: int(provider["port"]) for provider in providers}
