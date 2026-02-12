# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Library    String
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For Codec Test
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For Codec Test
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
Multi-codec offer negotiated successfully
    [Documentation]    INVITE with G.729, PCMA, PCMU, GSM codec offer.
    ...    Verifies rtpengine handles codec negotiation/filtering and the call completes.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_multi_codec.xml    service=${PBX1_DOMAIN}    duration=3000
    Verify Successful Calls    ${stat_file}    1

Multiple codec negotiation calls in sequence
    [Documentation]    Run several multi-codec calls to verify consistent behavior.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_multi_codec.xml    service=${PBX1_DOMAIN}
    ...    calls=3    call_rate=1    duration=2000
    Verify Successful Calls    ${stat_file}    3
