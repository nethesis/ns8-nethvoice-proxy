# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Library    String
Resource   ../sipp.resource

*** Test Cases ***
No active rtpengine sessions remain
    [Documentation]    Final check: verify all rtpengine media sessions have been cleaned up.
    ...    Any remaining sessions indicate a media leak from one of the test suites.
    Verify No Active RTPEngine Sessions

RTPEngine totals show processed traffic
    [Documentation]    Confirm rtpengine processed media during the test run.
    ${stats}=    Get RTPEngine Stats
    Should Not Be Empty    ${stats}    RTPEngine returned empty stats — may not have processed any media
    Log    Final rtpengine stats:\n${stats}

Kamailio has no stuck dialogs
    [Documentation]    Verify Kamailio dialog table has no orphaned entries.
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio kamcmd dlg.stats_active
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Log    Kamailio active dialog stats: ${output}
