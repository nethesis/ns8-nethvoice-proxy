#!/usr/bin/env python3

#
# Copyright (C) 2025 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

import json
import os
import subprocess


def run_command(command, input_text=None):
    return subprocess.run(
        command,
        input=input_text,
        check=True,
        capture_output=True,
        text=True,
    )


def psql_command(variables=None):
    command = [
        'podman',
        'exec',
        '-i',
        'postgres',
        'psql',
        '-v',
        'ON_ERROR_STOP=1',
        '-tA',
        '-U',
        os.environ["POSTGRES_USER"],
        os.environ["POSTGRES_DB"],
    ]
    for key, value in (variables or {}).items():
        command.extend(['-v', f'{key}={value}'])
    return command


def psql_json(query, variables=None):
    result = run_command(psql_command(variables), input_text=query)
    payload = result.stdout.strip()
    if not payload:
        return None
    return json.loads(payload)


def psql_exec(query, variables=None):
    run_command(psql_command(variables), input_text=query)


def kamcmd(*arguments):
    run_command(['podman', 'exec', '-i', 'kamailio', 'kamcmd', *arguments])


def kamcmd_output(*arguments):
    return run_command(['podman', 'exec', '-i', 'kamailio', 'kamcmd', *arguments]).stdout
