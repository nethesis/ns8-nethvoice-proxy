# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For Basic Calls
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For Basic Calls
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
Basic call through proxy completes successfully
    [Documentation]    Single INVITE->200->ACK->BYE call through Kamailio to PBX-1 UAS.
    ...    Verifies SIP signaling path: UAC -> Kamailio -> dispatcher -> UAS.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}    duration=3000
    Verify Successful Calls    ${stat_file}    1

Multiple sequential calls complete successfully
    [Documentation]    Run 3 sequential calls to verify stateful proxy handles call teardown correctly.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}    calls=3    call_rate=1    duration=2000
    Verify Successful Calls    ${stat_file}    3

OPTIONS keepalive receives 200 OK
    [Documentation]    Verify Kamailio's KEEPALIVE route responds to OPTIONS requests.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_options.xml    calls=1
