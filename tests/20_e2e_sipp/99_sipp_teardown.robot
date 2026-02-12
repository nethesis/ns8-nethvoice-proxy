# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource

*** Test Cases ***
Stop all SIPp UAS servers
    [Documentation]    Ensure all mock PBX UAS processes are terminated.
    Stop All UAS Servers
    # Also kill any stray SIPp processes
    Execute Command    pkill -f sipp 2>/dev/null || true    timeout=10s
    Sleep    2s

Remove e2e test routes
    [Documentation]    Clean up all domain routes created during e2e testing.
    Cleanup PBX Route    ${PBX1_DOMAIN}
    Cleanup PBX Route    ${PBX2_DOMAIN}

Remove e2e test trunks
    [Documentation]    Clean up all trunk rules created during e2e testing.
    Cleanup PBX Trunk    ${PBX1_TRUNK_PATTERN}
    Cleanup PBX Trunk    ${PBX2_TRUNK_PATTERN}

Clean up SIPp files on node
    [Documentation]    Remove all SIPp scenario files, logs, and stats from the node.
    Cleanup SIPp Artifacts

Verify clean state after e2e tests
    [Documentation]    Confirm the module is in a clean state with no test artifacts.
    ${routes}=    Run Task    module/${module_id}/list-routes    {}
    Log    Remaining routes after cleanup: ${routes}
    ${trunks}=    Run Task    module/${module_id}/list-trunks    {}
    Log    Remaining trunks after cleanup: ${trunks}
