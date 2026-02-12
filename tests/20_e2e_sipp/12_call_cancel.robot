# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For Cancel Test
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For Cancel Test
    # Use the no-answer UAS so it stays in ringing state for CANCEL testing
    ${pid}=    Start UAS Server    uas_no_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
CANCEL in-progress call propagates correctly
    [Documentation]    INVITE -> 180 Ringing -> CANCEL -> 487 Request Terminated.
    ...    Verifies proxy correctly forwards CANCEL and propagates 487.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_cancel_call.xml    service=${PBX1_DOMAIN}

No rtpengine session leak after cancelled call
    [Documentation]    Cancelled calls should not leave orphaned rtpengine sessions.
    Verify No Active RTPEngine Sessions
