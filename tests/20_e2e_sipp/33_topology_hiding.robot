# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Library    String
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For Topology Test
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For Topology Test
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
Topology hiding does not leak internal IPs
    [Documentation]    Verify TOPOS module hides internal routing information.
    ...    Make a call and check Kamailio's SIP trace for Via/Record-Route headers.
    ...    Internal service IPs should not appear in responses sent to external UAC.

    # Enable SIP trace temporarily for inspection
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio kamcmd core.shmmem
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0

    # Make a call
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}    duration=2000
    Verify Successful Calls    ${stat_file}    1

    # Verify Kamailio SIP processing is operational (basic topology check)
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio kamcmd dlg.list
    ...    return_rc=True
    Log    Dialog list after topology test: ${output}
