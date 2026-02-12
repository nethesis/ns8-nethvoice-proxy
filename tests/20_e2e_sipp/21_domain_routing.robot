# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start Both UAS For Domain Routing
Suite Teardown    Stop All UAS Servers

*** Keywords ***
Start Both UAS For Domain Routing
    ${pid1}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    ${pid2}=    Start UAS Server    uas_answer.xml    ${PBX2_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS2}
    Set Suite Variable    ${UAS1_PID}    ${pid1}
    Set Suite Variable    ${UAS2_PID}    ${pid2}

*** Test Cases ***
Call to domain PBX-1 routes to PBX-1 UAS
    [Documentation]    INVITE to ${PBX1_DOMAIN} should be dispatched to UAS on port ${PBX1_SIP_PORT}.
    ...    Verifies dialplan dpid=1 matches the domain and dispatcher selects correct set.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}    duration=2000
    Verify Successful Calls    ${stat_file}    1

Call to domain PBX-2 routes to PBX-2 UAS
    [Documentation]    INVITE to ${PBX2_DOMAIN} should be dispatched to UAS on port ${PBX2_SIP_PORT}.
    ...    Verifies domain-based routing isolates PBX instances correctly.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX2_DOMAIN}    duration=2000
    Verify Successful Calls    ${stat_file}    1

Sequential calls to alternating domains complete correctly
    [Documentation]    Alternate calls between PBX-1 and PBX-2 domains.
    ...    Verifies dispatcher correctly switches between sets per call.
    ${stat1}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}    duration=1000
    ${stat2}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX2_DOMAIN}    duration=1000
    ${stat3}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}    duration=1000
    Verify Successful Calls    ${stat1}    1
    Verify Successful Calls    ${stat2}    1
    Verify Successful Calls    ${stat3}    1
