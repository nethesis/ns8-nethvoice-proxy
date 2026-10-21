#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

"""Trunk registrations relayed by Kamailio for the NethVoice instances.

Used by the NethVoiceTrunkUnreachable alert (etc/metrics/alert-rules/proxy-telephony.yml):

- nethvoice_proxy_trunk_registration_status_code{nethvoice,trunk}: SIP code of
  the last answer, 408 when the provider did not answer
- nethvoice_proxy_trunk_options_status_code{nethvoice,trunk}: SIP code of the
  last answer to the OPTIONS (qualify) of an IP trunk, 408 when the provider
  did not answer. Any other code means the provider is alive.

Kamailio stores the last answer in the nvtrunkreg htable with key
"<dispatcher set id>|<To user>@<To domain>" (kamailio.cfg, route
NV_TRUNK_REG_REPLY), and in the nvtrunkopt htable with key
"<dispatcher set id>|<host>:<port>" of the To URI (route NV_TRUNK_OPT_TAG).
The set id is mapped to the NethVoice module id with the dispatcher table,
where the description is the NethVoice MODULE_ID: entries of a set id that
is not in the table belong to a removed instance and are skipped. Only UDP is tracked: see route
NV_TRUNK_REG_TAG.
"""

import concurrent.futures
import json
import subprocess
import sys
import urllib.error
import urllib.request

from .runner import CheckUnavailable

TIMEOUT = 4
RPC_URL = "http://127.0.0.1:5060/RPC"
REGISTRATIONS = "nvtrunkreg"
OPTIONS = "nvtrunkopt"


def escape(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def rpc(method, params, url=RPC_URL):
    """Call a Kamailio JSON-RPC method; raise CheckUnavailable when it cannot be called."""
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    request = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    # Kamailio listens on localhost: an HTTP proxy of the environment must not be used
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=TIMEOUT) as response:
            answer = json.load(response)
    except urllib.error.HTTPError as ex:
        # Kamailio answers, with an HTTP error: report its message, e.g. "No such htable"
        try:
            message = json.load(ex).get("error", {}).get("message", "")
        except (OSError, ValueError, AttributeError):
            message = ""
        ex.close()
        raise CheckUnavailable("Kamailio JSON-RPC %s failed: %s" % (method, message or "HTTP %d" % ex.code)) from None
    except (OSError, ValueError) as ex:
        raise CheckUnavailable("Kamailio JSON-RPC not reachable: %s" % (getattr(ex, "reason", None) or ex)) from None
    if "error" in answer:
        raise CheckUnavailable("Kamailio JSON-RPC %s failed: %s" % (method, answer["error"].get("message", "")))
    return answer.get("result")


def read_entries(table, call=rpc):
    """Return {key: value} of an htable."""
    entries = {}
    for bucket in call("htable.dump", [table]) or []:
        for item in bucket.get("slot") or []:
            entries[item.get("name")] = item.get("value")
    return entries


def read_instances(run=subprocess.run):
    """Return {dispatcher set id: NethVoice module id} from the dispatcher table."""
    script = 'exec psql -tA -F "|" -U "$POSTGRES_USER" "$POSTGRES_DB" -c "SELECT setid, description FROM dispatcher"'
    result = run(
        ["podman", "exec", "postgres", "sh", "-c", script],
        check=True,
        capture_output=True,
        text=True,
        timeout=TIMEOUT,
    )
    instances = {}
    for line in result.stdout.splitlines():
        setid, _, description = line.partition("|")
        if setid.strip() and description.strip():
            instances[setid.strip()] = description.strip()
    return instances


def codes_by_trunk(entries, instances, table):
    """Return {(nethvoice, trunk): SIP code} of the htable entries."""
    codes = {}
    # Sorted: when two set ids of the same instance have the same trunk, the result does not change between runs
    for key in sorted(entries, key=str):
        setid, _, trunk = str(key).partition("|")
        try:
            code = int(entries[key])
        except (TypeError, ValueError):
            code = None
        if not trunk or code is None:
            print("kamailio: unexpected %s entry %r skipped" % (table, key), file=sys.stderr)
            continue
        if setid not in instances:
            # Instance removed: its entries stay in the htable until autoexpire
            continue
        codes[(instances[setid], trunk)] = code
    return codes


def render(entries, instances, options=None):
    """Return the metrics in the Prometheus text format.

    entries: nvtrunkreg htable, options: nvtrunkopt htable.
    """
    codes = []
    for (nethvoice, trunk), code in sorted(codes_by_trunk(entries, instances, REGISTRATIONS).items()):
        labels = 'nethvoice="%s",trunk="%s"' % (escape(nethvoice), escape(trunk))
        codes.append("nethvoice_proxy_trunk_registration_status_code{%s} %d" % (labels, code))
    qualify = []
    for (nethvoice, trunk), code in sorted(codes_by_trunk(options or {}, instances, OPTIONS).items()):
        labels = 'nethvoice="%s",trunk="%s"' % (escape(nethvoice), escape(trunk))
        qualify.append("nethvoice_proxy_trunk_options_status_code{%s} %d" % (labels, code))
    lines = [
        "# HELP nethvoice_proxy_trunk_registration_status_code SIP code of the last answer to the trunk registration, 408 without answer",
        "# TYPE nethvoice_proxy_trunk_registration_status_code gauge",
        *codes,
        "# HELP nethvoice_proxy_trunk_options_status_code SIP code of the last answer to the OPTIONS of an IP trunk, 408 without answer",
        "# TYPE nethvoice_proxy_trunk_options_status_code gauge",
        *qualify,
    ]
    return "\n".join(lines) + "\n"


def collect(entries=read_entries, instances=read_instances):
    # The reads do not depend on each other: in parallel, a slow Kamailio or
    # postgres costs one TIMEOUT, not three
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        registrations = pool.submit(entries, REGISTRATIONS)
        options = pool.submit(entries, OPTIONS)
        mapping = pool.submit(instances)
        return render(registrations.result(), mapping.result(), options.result())
