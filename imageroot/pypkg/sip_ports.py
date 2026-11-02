#!/usr/bin/env python3

#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# SIP ports of the proxy. SIP_PORT (UDP and TCP) and SIPS_PORT (TLS) are the
# ports phones, gateways and trunks connect to. The service network toward
# NethVoice and the local listeners keep fixed ports.

import os

DEFAULT_SIP_PORT = 5060
DEFAULT_SIPS_PORT = 5061

# Ports of the listeners on the private address, used by clients in the
# local networks when the proxy is behind NAT
LOCAL_SIP_PORT = 6060
LOCAL_SIPS_PORT = 6061

RTP_PORTS = "10000-20000/udp"


def get_ports(env=None):
    """Return the (SIP, SIPS) ports from the environment, or the defaults."""
    env = os.environ if env is None else env
    sip_port = int(env.get("SIP_PORT") or DEFAULT_SIP_PORT)
    sips_port = int(env.get("SIPS_PORT") or DEFAULT_SIPS_PORT)
    return sip_port, sips_port


def validate_ports(sip_port, sips_port):
    """Return a list of (field, error) for an invalid pair of ports."""
    errors = []
    reserved = (LOCAL_SIP_PORT, LOCAL_SIPS_PORT)
    if sip_port in reserved:
        errors.append(("sip_port", "sip_port_reserved"))
    if sips_port in reserved:
        errors.append(("sips_port", "sips_port_reserved"))
    if sip_port == sips_port:
        errors.append(("sips_port", "sip_ports_must_differ"))
    return errors


def _tcp_ports(first, second):
    if second == first + 1:
        return [f"{first}-{second}/tcp"]
    return [f"{first}/tcp", f"{second}/tcp"]


def public_ports(sip_port, sips_port, local_networks=False):
    """Ports to open in the firewall public zone."""
    ports = _tcp_ports(sip_port, sips_port) + [f"{sip_port}/udp", RTP_PORTS]
    if local_networks:
        ports += _tcp_ports(LOCAL_SIP_PORT, LOCAL_SIPS_PORT) + [f"{LOCAL_SIP_PORT}/udp"]
    return ports


def port_forward_rules(local_networks, sip_port, sips_port):
    """Rich rules that redirect the traffic of the local networks to the
    local listeners."""
    rules = []
    for network in local_networks:
        if network:
            rules.append(f'rule family=ipv4 source address={network} forward-port port={sip_port} protocol=udp to-port={LOCAL_SIP_PORT}')
            rules.append(f'rule family=ipv4 source address={network} forward-port port={sip_port} protocol=tcp to-port={LOCAL_SIP_PORT}')
            rules.append(f'rule family=ipv4 source address={network} forward-port port={sips_port} protocol=tcp to-port={LOCAL_SIPS_PORT}')
    return rules
