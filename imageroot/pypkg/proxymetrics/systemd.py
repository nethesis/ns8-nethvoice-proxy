#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

"""State of the NethVoice Proxy services, read from systemd.

Used by the ServiceDown alert (etc/metrics/alert-rules/proxy-services.yml):

- nethvoice_proxy_service_up{service}: 1 when the unit is running or waiting
  for an automatic restart, 0 when it is down. Not exported when the unit is
  stopped and not expected to run: disabled, never started, or static
  (stopped or failed) and no running unit wants it. Static units (redis,
  rtpengine) have no [Install] section: kamailio pulls them in with Wants=.
- nethvoice_proxy_service_restarts_total{service}: automatic restarts done by
  systemd (NRestarts). A manual start or restart resets it to 0.
"""

import subprocess

# Unit names without ".service": the value of the "service" label
SERVICES = (
    "kamailio",
    "postgres",
    "redis",
    "rtpengine",
)
PROPERTIES = (
    "Id",
    "LoadState",
    "ActiveState",
    "UnitFileState",
    "NRestarts",
    "InactiveExitTimestampMonotonic",
    "WantedBy",
)
UP_STATES = ("active", "reloading", "activating")
TIMEOUT = 4


def read_units(services=SERVICES, run=subprocess.run):
    """Return the properties of every service, one dict per unit."""
    result = run(
        ["systemctl", "--user", "show", "--property=" + ",".join(PROPERTIES), "--"]
        + [service + ".service" for service in services],
        check=True,
        capture_output=True,
        text=True,
        timeout=TIMEOUT,
    )
    return parse_show(result.stdout)


def parse_show(text):
    """Parse "systemctl show" output: units are separated by empty lines."""
    units = []
    current = {}
    for line in text.splitlines():
        if not line.strip():
            if current:
                units.append(current)
                current = {}
            continue
        key, _, value = line.partition("=")
        current[key] = value
    if current:
        units.append(current)
    return units


def service_up(unit, running=()):
    """Return 1 (up), 0 (down) or None (not expected to run).

    running is the set of unit ids that are up: a stopped or failed static
    unit is down only when one of them wants it.
    """
    state = unit.get("ActiveState")
    # "activating" also covers the wait before an automatic restart: a crash
    # loop is reported by the restart counter, not as a stopped service
    if state in UP_STATES:
        return 1
    # A static unit stays "failed" until reset-failed, also after the units
    # that want it were stopped on purpose
    if unit.get("UnitFileState") == "static":
        return 0 if set(unit.get("WantedBy", "").split()) & set(running) else None
    if state == "failed":
        return 0
    ran = int(unit.get("InactiveExitTimestampMonotonic") or 0) > 0
    if unit.get("UnitFileState") == "enabled" and ran:
        return 0
    return None


def render(units, prefix="nethvoice_proxy"):
    """Return the metrics in the Prometheus text format."""
    up = []
    restarts = []
    running = {unit["Id"] for unit in units if unit.get("ActiveState") in UP_STATES}
    for unit in units:
        if unit.get("LoadState") != "loaded":
            continue
        service = unit["Id"][: -len(".service")]
        restarts.append('%s_service_restarts_total{service="%s"} %d' % (prefix, service, int(unit.get("NRestarts") or 0)))
        value = service_up(unit, running)
        if value is not None:
            up.append('%s_service_up{service="%s"} %d' % (prefix, service, value))
    lines = [
        "# HELP %s_service_up 1 if the service is running or restarting, 0 if it is down" % prefix,
        "# TYPE %s_service_up gauge" % prefix,
        *up,
        "# HELP %s_service_restarts_total Automatic restarts done by systemd" % prefix,
        "# TYPE %s_service_restarts_total counter" % prefix,
        *restarts,
    ]
    return "\n".join(lines) + "\n"


def collect():
    return render(read_units())
