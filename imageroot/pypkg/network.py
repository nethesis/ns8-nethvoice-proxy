#!/usr/bin/env python3

#
# Copyright (C) 2024 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import ipaddress
import json
import subprocess


def __filter_interface(interface, excluded_interfaces=[]):
    """
    Filter the interfaces that are not useful for the configuration.
    """
    # filter by name
    if interface["ifname"] in excluded_interfaces:
        return False

    # filter by configuration status
    if "addr_info" not in interface or interface["addr_info"] == []:
        return False

    # return True if the interface is not filtered
    return True


def __format_interface(interface, excluded_families=[]):
    """
    Format the interface that can be used internally for responses.
    """
    interface_data = {
        "name": interface["ifname"],
        "addresses": [],
    }
    for address in interface["addr_info"]:
        if address["family"] == "inet" and "inet" not in excluded_families:
            network = ipaddress.IPv4Network(address["local"] + "/" + str(address["prefixlen"]), strict=False)
            interface_data["addresses"].append({
                "address": str(ipaddress.IPv4Address(address["local"])),
                "network": str(network),
                "family": "inet",
            })
        elif address["family"] == "inet6" and "inet6" not in excluded_families:
            network = ipaddress.IPv6Network(address["local"] + "/" + str(address["prefixlen"]), strict=False)
            interface_data["addresses"].append({
                "address": str(ipaddress.IPv6Address(address["local"])),
                "network": str(network),
                "family": "inet6",
            })

    return interface_data


def list_interfaces(excluded_interfaces=[], excluded_families=[]):
    """
    Returns a list of interfaces with their available addresses.
    """
    subprocess_result = subprocess.run(["ip", "-j", "addr"], check=True, capture_output=True)
    return [__format_interface(interface, excluded_families) for interface in json.loads(subprocess_result.stdout) if __filter_interface(interface, excluded_interfaces)]
