# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Library    String
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For SRTP Test
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For SRTP Test
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
SRTP call completes through proxy with transcoding
    [Documentation]    INVITE with RTP/SAVP (SRTP) SDP offer.
    ...    Rtpengine should transcode SRTP to RTP for the internal PBX side.
    ...    Verifies SDP rewriting and crypto attribute handling.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_srtp_call.xml    service=${PBX1_DOMAIN}    duration=3000
    Verify Successful Calls    ${stat_file}    1

No rtpengine session leak after SRTP call
    Verify No Active RTPEngine Sessions
