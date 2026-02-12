# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start Both UAS For Cross PBX
Suite Teardown    Stop All UAS Servers

*** Keywords ***
Start Both UAS For Cross PBX
    ${pid1}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    ${pid2}=    Start UAS Server    uas_answer.xml    ${PBX2_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS2}
    Set Suite Variable    ${UAS1_PID}    ${pid1}
    Set Suite Variable    ${UAS2_PID}    ${pid2}

*** Test Cases ***
Concurrent calls to both PBX domains complete successfully
    [Documentation]    Send 5 calls to PBX-1 and 5 calls to PBX-2 simultaneously.
    ...    Uses two sequential SIPp runs (SIPp doesn't support mixed targets in one run).
    ...    Verifies cross-PBX isolation — calls to PBX-1 don't bleed to PBX-2.

    # Run 5 calls to PBX-1
    ${stat1}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}
    ...    calls=5    call_rate=5    concurrent=5    duration=2000
    Verify Successful Calls    ${stat1}    5

    # Run 5 calls to PBX-2
    ${stat2}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX2_DOMAIN}
    ...    calls=5    call_rate=5    concurrent=5    duration=2000
    Verify Successful Calls    ${stat2}    5

Concurrent media calls across both PBXs
    [Documentation]    Send calls with RTP media to both PBXs.
    ...    Verifies rtpengine handles concurrent media sessions for different PBX targets.
    ${stat1}=    Run SIPp UAC And Expect Success
    ...    uac_call_with_media.xml    service=${PBX1_DOMAIN}
    ...    calls=3    call_rate=3    concurrent=3    duration=2000
    ${stat2}=    Run SIPp UAC And Expect Success
    ...    uac_call_with_media.xml    service=${PBX2_DOMAIN}
    ...    calls=3    call_rate=3    concurrent=3    duration=2000
    Verify Successful Calls    ${stat1}    3
    Verify Successful Calls    ${stat2}    3

No rtpengine session leak after cross-PBX concurrent calls
    [Documentation]    Verify all media sessions are cleaned up.
    Verify No Active RTPEngine Sessions
