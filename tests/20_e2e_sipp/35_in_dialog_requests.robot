# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For In-Dialog Test
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For In-Dialog Test
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
Re-INVITE hold and resume within dialog
    [Documentation]    Established call with re-INVITE to put on hold (sendonly) then resume (sendrecv).
    ...    Verifies Kamailio's WITHINDLG route handles in-dialog INVITE correctly.
    ...    Verifies rtpengine updates media direction on re-INVITE.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_reinvite.xml    service=${PBX1_DOMAIN}    duration=2000
    Verify Successful Calls    ${stat_file}    1

Multiple hold/resume cycles
    [Documentation]    Run several re-INVITE cycles to verify dialog state consistency.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_reinvite.xml    service=${PBX1_DOMAIN}
    ...    calls=3    call_rate=1    duration=1000
    Verify Successful Calls    ${stat_file}    3

No rtpengine session leak after in-dialog tests
    Verify No Active RTPEngine Sessions
