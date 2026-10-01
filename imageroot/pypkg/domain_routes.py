#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import json
import os
import subprocess


def run_route_query(domain, query, addresses=None, *, read_only=False):
    """Resolve one domain and apply its query in a checked transaction."""
    # Lock before looking up the route: the schema has no unique domain key.
    # Readers also lock so they cannot observe a different set of addresses.
    lock_mode = "SHARE" if read_only else "SHARE ROW EXCLUSIVE"
    sql = f"""
BEGIN;
LOCK TABLE nethvoice_proxy_routes, domain, dialplan, dispatcher IN {lock_mode} MODE;
CREATE TEMP TABLE selected_route ON COMMIT DROP AS
    SELECT * FROM nethvoice_proxy_routes
    WHERE route_type = 'domain' AND target = :'domain';
{query}
COMMIT;
"""
    # psql quotes :'variables' as SQL literals, including address descriptions.
    result = subprocess.run(
        [
            'podman', 'exec', '-i', 'postgres', 'psql', '-X', '-qAt',
            '-v', 'ON_ERROR_STOP=1', '-v', f'domain={domain}',
            '-v', f'addresses={json.dumps(addresses)}',
            '-U', os.environ['POSTGRES_USER'], os.environ['POSTGRES_DB'],
        ],
        input=sql, text=True, stdout=subprocess.PIPE, check=True,
    )
    return result.stdout
