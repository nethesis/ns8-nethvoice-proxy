# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Library    String
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS With RTP Echo
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS With RTP Echo
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
Call with RTP media flow completes successfully
    [Documentation]    INVITE with SDP and RTP media stream through rtpengine.
    ...    Verifies rtpengine forwards media packets between UAC and UAS.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_call_with_media.xml    service=${PBX1_DOMAIN}    duration=3000
    Verify Successful Calls    ${stat_file}    1

No rtpengine session leak after media call
    [Documentation]    After the media call ends, verify rtpengine cleaned up sessions.
    Verify No Active RTPEngine Sessions

RTPEngine stats show processed packets
    [Documentation]    Verify rtpengine has processed media (non-zero packet counters).
    ${stats}=    Get RTPEngine Stats
    Should Not Be Empty    ${stats}
    Log    Post-call rtpengine stats: ${stats}
