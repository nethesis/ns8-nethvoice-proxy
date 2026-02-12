# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start Both UAS For Trunk Routing
Suite Teardown    Stop All UAS Servers

*** Keywords ***
Start Both UAS For Trunk Routing
    ${pid1}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    ${pid2}=    Start UAS Server    uas_answer.xml    ${PBX2_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS2}
    Set Suite Variable    ${UAS1_PID}    ${pid1}
    Set Suite Variable    ${UAS2_PID}    ${pid2}

*** Test Cases ***
Trunk call matching PBX-1 pattern routes to PBX-1
    [Documentation]    Inbound call with number matching ${PBX1_TRUNK_PATTERN} should route to PBX-1.
    ...    Verifies dialplan dpid=2 pattern matching for trunk routing.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=1001    duration=2000
    Verify Successful Calls    ${stat_file}    1

Trunk call matching PBX-2 pattern routes to PBX-2
    [Documentation]    Inbound call with number matching ${PBX2_TRUNK_PATTERN} should route to PBX-2.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=2001    duration=2000
    Verify Successful Calls    ${stat_file}    1

Multiple trunk calls with different patterns
    [Documentation]    Mix of calls with PBX-1 and PBX-2 trunk patterns.
    ${s1}=    Run SIPp UAC And Expect Success    uac_basic_call.xml    service=1002    duration=1000
    ${s2}=    Run SIPp UAC And Expect Success    uac_basic_call.xml    service=2002    duration=1000
    ${s3}=    Run SIPp UAC And Expect Success    uac_basic_call.xml    service=1003    duration=1000
    Verify Successful Calls    ${s1}    1
    Verify Successful Calls    ${s2}    1
    Verify Successful Calls    ${s3}    1
