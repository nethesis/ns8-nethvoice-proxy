#!/usr/bin/env python3

#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Proxy bypass: the SIP traffic over UDP of some source addresses, such as a
# local gateway, is redirected to the SIP port of a NethVoice instance of the
# same node and never reaches Kamailio.

import fcntl
import ipaddress
import json
import os
import re

import sip_ports

# A rich rule with a negative priority is evaluated before the ones without
# priority, such as the redirect rules of the local networks: the bypass wins
# even when the source address belongs to a local network.
RULE_PRIORITY = -10

# Rich rules of the proxy bypass that are, or may be, in the firewall. The
# file is written before the firewall changes and again after them, so the
# rules of a failed change are still known and removed by the next one. It is
# not part of the backup: the rules belong to the node.
APPLIED_RULES_FILE = "bypass_rules.json"
LOCK_FILE = "bypass_rules.lock"


def parse_sources(value):
    """Return the bypass sources saved in the BYPASS_SOURCES variable, a
    comma-separated list of address:module_id:port:module_uuid items. The
    port is the one the firewall rule was created with. The UUID of the
    NethVoice instance is missing in the items saved by the first builds of
    the proxy bypass."""
    sources = []
    for item in (value or "").split(","):
        fields = item.split(":")
        if len(fields) not in (3, 4) or not fields[2].isdigit():
            continue
        source = {"address": fields[0], "module_id": fields[1], "port": int(fields[2])}
        if len(fields) == 4 and fields[3]:
            source["module_uuid"] = fields[3]
        sources.append(source)
    return sources


def format_sources(sources):
    """Return the value of the BYPASS_SOURCES variable."""
    items = []
    for source in sources:
        item = f'{source["address"]}:{source["module_id"]}:{source["port"]}'
        if source.get("module_uuid"):
            item += f':{source["module_uuid"]}'
        items.append(item)
    return ",".join(items)


def acquire_lock():
    """Wait for the exclusive lock of the proxy bypass and return it. The
    lock is released when the returned file is closed or the process ends.
    configure-module, destroy-module and the handler of the NethVoice events
    read the saved sources and change the firewall while they hold it, so
    one of them cannot apply a list the other has just replaced."""
    lock = open(os.path.join(os.environ.get("AGENT_STATE_DIR", "."), LOCK_FILE), "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    return lock


def listen_address(env=None):
    """Return the address the proxy listens on: the private one behind NAT,
    otherwise the public one."""
    env = os.environ if env is None else env
    return env.get("PRIVATE_IP") or env.get("PUBLIC_IP") or ""


def rules(sources, sip_port, destination=""):
    """Rich rules of the bypass sources. The first one redirects the SIP
    traffic over UDP to the NethVoice instance: it matches only destination,
    the address the proxy listens on, so the traffic the source sends to
    another address of the node is left alone. The second one opens the SIP
    port of the instance: Asterisk writes it in its Contact header, so the
    source sends there the requests that follow the first one, such as ACK
    and BYE."""
    result = []
    for source in sources:
        match = f'rule priority={RULE_PRIORITY} family=ipv4 source address={source["address"]}'
        to_proxy = f"{match} destination address={destination}" if destination else match
        result.append(f'{to_proxy} forward-port port={sip_port} protocol=udp to-port={source["port"]}')
        result.append(f'{match} port port={source["port"]} protocol=udp accept')
    return result


def _redirect_key(rule):
    """Return the comparable form of a redirect rule without its target
    port, or None for another kind of rule."""
    key = sip_ports.rule_key(rule)
    if "forward-port" not in key:
        return None
    return frozenset(token for token in key if not token.startswith("to-port="))


def _is_managed_redirect(rule, sip_port, destination):
    """Tell if a rule listed by the firewall has the form of the redirect of
    a bypass source: priority, address of the proxy as destination and SIP
    port of the proxy over UDP."""
    if not destination or "forward-port" not in rule:
        return False
    fields = dict(re.findall(r'(priority|destination address|port|protocol)="?([^" ]+)"?', rule.split("to-port")[0]))
    return (
        fields.get("priority") == str(RULE_PRIORITY)
        and fields.get("destination address") == destination
        and fields.get("port") == str(sip_port)
        and fields.get("protocol") == "udp"
    )


def stale_rules(applied_rules, new_rules, firewall_rules, sip_port=None, destination=""):
    """Return the rules to remove from the firewall: the applied ones that
    are not part of the new ones. The update of a NethVoice instance that
    moves its SIP port rewrites the target port of the redirect rules, so a
    redirect is searched in the firewall whatever its target port is.

    That update can also add its rewritten redirect after the source was
    removed here, when the two run at the same time. So every redirect of
    the firewall that has the form of the ones created here, and is not one
    of the new rules, is removed too."""
    new_keys = {sip_ports.rule_key(rule) for rule in new_rules}
    stale = [
        listed for listed in firewall_rules
        if sip_ports.rule_key(listed) not in new_keys and _is_managed_redirect(listed, sip_port, destination)
    ]
    for rule in applied_rules:
        if sip_ports.rule_key(rule) in new_keys:
            continue
        stale.append(rule)
        redirect = _redirect_key(rule)
        if redirect is None:
            continue
        for listed in firewall_rules:
            key = sip_ports.rule_key(listed)
            if key not in new_keys and key != sip_ports.rule_key(rule) and _redirect_key(listed) == redirect:
                stale.append(listed)
    return list(dict.fromkeys(stale))


def _applied_rules_path():
    return os.path.join(os.environ.get("AGENT_STATE_DIR", "."), APPLIED_RULES_FILE)


def read_applied_rules():
    """Return the rules recorded by the last firewall change. Without the
    file, they are the rules of the saved sources as the first builds of the
    proxy bypass created them, with no destination address."""
    try:
        with open(_applied_rules_path()) as fp:
            return json.load(fp)
    except FileNotFoundError:
        return rules(parse_sources(os.environ.get("BYPASS_SOURCES")), sip_ports.get_ports()[0])


def write_applied_rules(applied_rules):
    path = _applied_rules_path()
    with open(path + ".tmp", "w") as fp:
        json.dump(applied_rules, fp)
    os.replace(path + ".tmp", path)


def reconcile(sources, sip_port, destination, firewall=None):
    """Make the firewall match the bypass sources and raise an exception on
    failure. firewall is the agent module."""
    if firewall is None:
        import agent as firewall

    applied_rules = read_applied_rules()
    new_rules = rules(sources, sip_port, destination)
    # A module that never had a bypass source has nothing to look for
    if not applied_rules and not new_rules and not os.path.exists(_applied_rules_path()):
        return
    # Record the new rules before adding them: if this change fails halfway
    # the next one still knows what to remove
    write_applied_rules(applied_rules + [rule for rule in new_rules if rule not in applied_rules])

    stale = stale_rules(applied_rules, new_rules, firewall.list_rich_rules(raise_on_error=True), sip_port, destination)
    if stale and not firewall.remove_rich_rules(stale):
        raise RuntimeError("Failed to remove the proxy bypass rules")
    if new_rules and not firewall.add_rich_rules(new_rules):
        raise RuntimeError("Failed to add the proxy bypass rules")
    # The node actions do not report the failure of a single rule
    current = {sip_ports.rule_key(rule) for rule in firewall.list_rich_rules(raise_on_error=True)}
    if any(sip_ports.rule_key(rule) in current for rule in stale):
        raise RuntimeError("Some proxy bypass rules were not removed")
    if not all(sip_ports.rule_key(rule) in current for rule in new_rules):
        raise RuntimeError("Some proxy bypass rules were not added")
    write_applied_rules(new_rules)


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


def resolve_sources(sources, instance_ports, instance_uuids=None):
    """Return (resolved, missing): the sources with the SIP port and the UUID
    of their NethVoice instance, and the ones whose instance is not on the
    node."""
    resolved = []
    missing = []
    for source in sources:
        port = instance_ports.get(source["module_id"])
        if port is None:
            missing.append(source)
            continue
        item = {"address": source["address"], "module_id": source["module_id"], "port": port}
        module_uuid = (instance_uuids or {}).get(source["module_id"])
        if module_uuid:
            item["module_uuid"] = module_uuid
        resolved.append(item)
    return resolved, missing


def restored_sources(sources, instance_uuids):
    """Return the sources of a backup for this node. The module ID of the
    backup can belong to another NethVoice instance here, so the instance is
    found by its UUID and the source gets its current module ID. A source
    whose instance is not on the node is left out."""
    module_ids = {module_uuid: module_id for module_id, module_uuid in instance_uuids.items()}
    return [
        {"address": source["address"], "module_id": module_ids[source["module_uuid"]]}
        for source in sources
        if source.get("module_uuid") in module_ids
    ]


def follow_instance_ports(env, instance_ports, firewall=None):
    """Move the rules of the saved sources to the current SIP port of their
    NethVoice instance. env is the environment read while holding the lock.
    Return the sources to save, or None when they did not change. The source
    of an instance that is not on the node keeps its port: it is dropped by
    the next configure-module."""
    saved_sources = parse_sources(env.get("BYPASS_SOURCES"))
    if not saved_sources and not os.path.exists(_applied_rules_path()):
        return None
    sources = [
        dict(source, port=instance_ports.get(source["module_id"], source["port"]))
        for source in saved_sources
    ]
    reconcile(sources, sip_ports.get_ports(env)[0], listen_address(env), firewall)
    return None if sources == saved_sources else sources


def local_instances():
    """Return the SIP port over UDP and the UUID of the NethVoice instances
    of this node, by module ID."""
    import agent

    rdb = agent.redis_connect(use_replica=True)
    providers = agent.list_service_providers(rdb, "sip", "udp", {"node_id": os.environ["NODE_ID"]})
    return {
        provider["module_id"]: {"port": int(provider["port"]), "module_uuid": provider.get("module_uuid") or ""}
        for provider in providers
    }


def local_instance_ports():
    """Return the SIP port over UDP of the NethVoice instances of this node,
    by module ID."""
    return {module_id: instance["port"] for module_id, instance in local_instances().items()}
