# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource

*** Test Cases ***
Install SIPp on the node
    [Documentation]    Ensure SIPp is installed and available
    Install SIPp On Node

Upload SIPp scenario files
    [Documentation]    Copy all SIPp XML scenarios to the NS8 node
    Upload SIPp Scenarios

Verify SIPp is working
    [Documentation]    Confirm SIPp binary is functional
    Verify SIPp Available

Verify Kamailio is responding
    [Documentation]    Confirm Kamailio is up before running call tests
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio kamcmd core.uptime
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    uptime

Verify rtpengine is responding
    [Documentation]    Confirm rtpengine is up before running media tests
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec rtpengine rtpengine-ctl list totals
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0

Configure PBX-1 route for e2e tests
    [Documentation]    Create domain route for PBX-1 pointing to SIPp UAS port
    Setup PBX Route    ${PBX1_DOMAIN}    ${PBX1_SIP_PORT}    e2e-pbx1
    ${response}=    Run Task    module/${module_id}/get-route    {"domain":"${PBX1_DOMAIN}"}
    Should Not Be Empty    ${response}
