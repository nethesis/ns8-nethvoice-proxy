# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start PBX1 No Answer UAS
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 No Answer UAS
    # UAS sends 180 but never answers — call will time out or be cancelled
    ${pid}=    Start UAS Server    uas_no_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
Call with no answer times out properly
    [Documentation]    INVITE -> 180 Ringing -> timeout (SIPp -timeout triggers CANCEL).
    ...    Verifies the proxy handles timeout gracefully without hanging.
    [Tags]    slow
    # Use a short SIPp timeout (10s) to avoid waiting for Kamailio's FR_INV_TIMEOUT (120s)
    ${rc}    ${stat_file}=    Run SIPp UAC And Expect Failure
    ...    uac_cancel_call.xml    service=${PBX1_DOMAIN}    extra_args=-timeout 10

No rtpengine session leak after timeout
    [Documentation]    Timed-out calls should not leave orphaned rtpengine sessions.
    Verify No Active RTPEngine Sessions
