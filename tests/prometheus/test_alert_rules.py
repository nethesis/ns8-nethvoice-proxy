#!/usr/bin/env python3
#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#
"""Generate and test the publisher's rules with Prometheus 3.5.3, without NS8."""

import argparse
import copy
import json
from pathlib import Path
import re
import runpy
import subprocess
import tempfile
import types
from unittest import mock

import yaml


ROOT = Path(__file__).resolve().parents[2]
MODULES = ("nethvoice-proxy1", "nethvoice-proxy2")
INSTANCE = "10.5.4.1:20137"
SERVICES = ("kamailio.service", "rtpengine.service", "postgres.service", "redis.service")
EXPORTER = "systemd-exporter.service"
NON_ACTIVE_STATES = ("reloading", "inactive", "failed", "activating", "deactivating", "maintenance", "refreshing")


def series_name(metric, labels):
    return metric + "{" + ",".join(f"{k}={json.dumps(v)}" for k, v in sorted(labels.items())) + "}"


def target_labels(module=MODULES[0], instance=INSTANCE):
    return {"module_id": module, "instance": instance, "node": "7", "job": "modules", "target_type": "systemd"}


class Scenario:
    def __init__(self, name, rules):
        self.rules = rules
        self.data = {"name": name, "interval": "30s", "input_series": [], "alert_rule_test": [], "promql_expr_test": []}

    def series(self, metric, labels, values):
        self.data["input_series"].append({"series": series_name(metric, labels), "values": values})

    def target(self, active=None, missing=(), up="1x40", module=MODULES[0], instance=INSTANCE):
        labels = target_labels(module, instance)
        self.series("up", labels, up)
        for unit in SERVICES:
            if unit not in missing:
                self.series("systemd_unit_state", dict(labels, name=unit, state="active", type="simple"),
                            (active or {}).get(unit, "1x40"))

    def check(self, time, pending=(), firing=()):
        def expand(items):
            return [(MODULES[0], INSTANCE, item) if isinstance(item, str) else item for item in items]

        pending, firing = expand(pending), expand(firing)
        for unit, rule in self.rules.items():
            alerts = []
            for module, instance, fired_unit in firing:
                if unit != fired_unit:
                    continue
                labels = dict(target_labels(module, instance), **rule["labels"])
                annotations = {
                    key: value.replace("{{ $labels.module_id }}", module).replace("{{ $labels.node }}", "7")
                    for key, value in rule["annotations"].items()
                }
                alerts.append({"exp_labels": labels, "exp_annotations": annotations})
            self.data["alert_rule_test"].append({
                "eval_time": time, "alertname": rule["alert"], "exp_alerts": alerts,
            })
        samples = []
        for state, items in (("pending", pending), ("firing", firing)):
            for module, instance, unit in items:
                rule = self.rules[unit]
                labels = dict(target_labels(module, instance), **rule["labels"], alertname=rule["alert"], alertstate=state)
                samples.append({"labels": series_name("ALERTS", labels), "value": 1})
        # Check the full set, including pending alerts that alert_rule_test omits.
        self.data["promql_expr_test"].append({
            "eval_time": time, "expr": 'ALERTS{alertname=~"NethVoiceProxy.*"}', "exp_samples": samples,
        })


def scenarios(rules):
    tests = []

    def scenario(name):
        case = Scenario(name, rules)
        tests.append(case.data)
        return case

    case = scenario("healthy services and unrelated targets never alert")
    case.target()
    case.series("up", dict(target_labels(), target_type="postgres"), "0x40")
    case.series("up", target_labels("unrelated1"), "0x40")
    case.series("systemd_unit_state", dict(target_labels(), name="get-certificate.service", state="active"), "0x40")
    case.check("10m")

    for unit in SERVICES:
        for state in NON_ACTIVE_STATES:
            case = scenario(f"{unit}: {state}, exact five-minute threshold and recovery")
            case.target(active={unit: "0x11 1x28"})
            case.series("systemd_unit_state", dict(target_labels(), name=unit, state=state, type="simple"), "1x11 0x28")
            case.check("0m", pending=[unit])
            case.check("4m30s", pending=[unit])
            case.check("5m", firing=[unit])
            case.check("6m")

        case = scenario(f"{unit}: missing unit while exporter remains reachable")
        case.target(missing=[unit])
        case.check("4m30s", pending=[unit])
        case.check("5m", firing=[unit])

        case = scenario(f"{unit}: stale active sample becomes a missing unit")
        case.target(active={unit: "1x1 stale _x38"})
        case.check("30s")
        case.check("1m", pending=[unit])
        case.check("5m30s", pending=[unit])
        case.check("6m", firing=[unit])

        case = scenario(f"{unit}: a brief restart resets the five-minute timer")
        case.target(active={unit: "1 0x7 1 0x11 1x19"})
        case.check("4m", pending=[unit])
        case.check("4m30s")
        case.check("9m30s", pending=[unit])
        case.check("10m", firing=[unit])
        case.check("11m")

    case = scenario("exporter outage suppresses missing and inactive services")
    case.target(up="0x11 1x28", active={unit: "0x11 1x28" for unit in SERVICES}, missing=["redis.service"])
    case.check("0m", pending=[EXPORTER])
    case.check("4m30s", pending=[EXPORTER])
    case.check("5m", firing=[EXPORTER])
    case.check("6m", pending=["redis.service"])
    case.check("10m30s", pending=["redis.service"])
    case.check("11m", firing=["redis.service"])

    case = scenario("brief exporter restart never fires")
    case.target(up="1 0x7 1x31")
    case.check("4m", pending=[EXPORTER])
    case.check("4m30s")
    case.check("10m")

    case = scenario("a fired service alert clears during an exporter outage")
    case.target(up="1x11 0x11 1x17", active={"kamailio.service": "0x40"})
    case.check("5m", firing=["kamailio.service"])
    case.check("6m", pending=[EXPORTER])
    case.check("11m", firing=[EXPORTER])
    case.check("12m", pending=["kamailio.service"])
    case.check("17m", firing=["kamailio.service"])

    case = scenario("removing the scrape target clears alerts")
    case.target(up="1x11 stale _x28", missing=SERVICES)
    case.check("5m", firing=SERVICES)
    case.check("6m")
    case.check("12m")

    case = scenario("services fire and recover independently")
    case.target(active={"kamailio.service": "0x11 1x28", "redis.service": "1x1 0x38"})
    case.check("5m", firing=["kamailio.service"], pending=["redis.service"])
    case.check("6m", firing=["redis.service"])
    case.check("10m", firing=["redis.service"])

    # Identical endpoints deliberately exercise module_id vector matching.
    case = scenario("another module's active unit cannot mask a missing unit")
    case.target(missing=["kamailio.service"])
    case.target(module=MODULES[1], active={"redis.service": "0x40"})
    case.check("5m", firing=["kamailio.service", (MODULES[1], INSTANCE, "redis.service")])

    case = scenario("same-name alerts in different modules recover independently")
    case.target(active={"kamailio.service": "0x11 1x28"})
    case.target(module=MODULES[1], active={"kamailio.service": "0x40"})
    case.check("5m", firing=["kamailio.service", (MODULES[1], INSTANCE, "kamailio.service")])
    case.check("6m", firing=[(MODULES[1], INSTANCE, "kamailio.service")])

    case = scenario("an exporter outage only suppresses its own module")
    case.target(up="0x40", missing=SERVICES)
    case.target(module=MODULES[1], missing=["kamailio.service"])
    case.check("5m", firing=[EXPORTER, (MODULES[1], INSTANCE, "kamailio.service")])

    case = scenario("a healthy endpoint cannot mask a failed endpoint in the same module")
    case.target()
    case.target(instance="10.5.4.2:20137", missing=["kamailio.service"])
    case.check("5m", firing=[(MODULES[0], "10.5.4.2:20137", "kamailio.service")])
    return tests


def run(promtool, output):
    version = subprocess.run([promtool, "--version"], check=True, capture_output=True, text=True)
    if not re.search(r"version 3\.5\.3\b", version.stdout + version.stderr):
        raise SystemExit("These tests require promtool version 3.5.3")
    with mock.patch.dict("sys.modules", {"agent": types.ModuleType("agent")}):
        publisher = runpy.run_path(str(ROOT / "imageroot/bin/prometheus-alert-rules"))
    documents = publisher["build_rule_sets"]({
        "NETHVOICE_PROXY_SYSTEMD_EXPORTER_PORT": "20137", "SYSTEMD_EXPORTER_PROMETHEUS_PATH": "/test",
    })
    authored = {"groups": [group for doc in documents.values() for group in yaml.safe_load(doc)["groups"]]}
    rules = {rule["labels"]["service"]: rule for group in authored["groups"] for rule in group["rules"]}
    scoped = {"groups": []}
    for module in MODULES:
        for field, document in documents.items():
            for original in yaml.safe_load(document)["groups"]:
                group = copy.deepcopy(original)
                group["name"] = f'ns8:{module}:{field}:{group["name"]}'
                for rule in group["rules"]:
                    # Apply the contract's exact matcher and static identity label.
                    result = subprocess.run([
                        promtool, "--experimental", "promql", "label-matchers", "set", "--",
                        rule["expr"], "module_id", module,
                    ], check=True, capture_output=True, text=True)
                    rule["expr"] = result.stdout.strip()
                    rule["labels"]["module_id"] = module
                scoped["groups"].append(group)
    tests = scenarios(rules)
    for filename, document in (
        ("authored.yml", authored), ("scoped.yml", scoped),
        ("tests.yml", {"rule_files": ["scoped.yml"], "evaluation_interval": "30s", "tests": tests}),
    ):
        (output / filename).write_text(yaml.safe_dump(document, allow_unicode=True, sort_keys=False))
    subprocess.run([promtool, "check", "rules", "authored.yml", "scoped.yml"], cwd=output, check=True)
    subprocess.run([promtool, "test", "rules", "tests.yml"], cwd=output, check=True)
    print(f"Passed {len(tests)} scenarios with promtool 3.5.3")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--promtool", default="promtool", help="Path to the Prometheus 3.5.3 promtool binary")
    parser.add_argument("--output-dir", type=Path, help="Keep generated rules and fixtures in this directory")
    args = parser.parse_args()
    if args.output_dir:
        args.output_dir.mkdir(parents=True, exist_ok=True)
        run(args.promtool, args.output_dir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix="proxy-alert-tests-") as directory:
            run(args.promtool, Path(directory))


if __name__ == "__main__":
    main()
