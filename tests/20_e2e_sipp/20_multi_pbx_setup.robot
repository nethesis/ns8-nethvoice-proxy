# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource

*** Test Cases ***
Configure PBX-2 route for e2e tests
    [Documentation]    Add a second domain route for multi-PBX testing.
    Setup PBX Route    ${PBX2_DOMAIN}    ${PBX2_SIP_PORT}    e2e-pbx2
    ${response}=    Run Task    module/${module_id}/get-route    {"domain":"${PBX2_DOMAIN}"}
    Should Not Be Empty    ${response}

Configure trunk patterns for multi-PBX routing
    [Documentation]    Add trunk rules that route different number patterns to different PBXs.
    Setup PBX Trunk    ${PBX1_TRUNK_PATTERN}    ${PBX1_SIP_PORT}    e2e-trunk-pbx1
    Setup PBX Trunk    ${PBX2_TRUNK_PATTERN}    ${PBX2_SIP_PORT}    e2e-trunk-pbx2
    ${response}=    Run Task    module/${module_id}/list-trunks    {}
    Log    Trunk list: ${response}

Verify both PBX routes are configured
    [Documentation]    Confirm both domain routes exist in the routing table.
    ${r1}=    Run Task    module/${module_id}/get-route    {"domain":"${PBX1_DOMAIN}"}
    ${r2}=    Run Task    module/${module_id}/get-route    {"domain":"${PBX2_DOMAIN}"}
    Should Not Be Empty    ${r1}
    Should Not Be Empty    ${r2}
