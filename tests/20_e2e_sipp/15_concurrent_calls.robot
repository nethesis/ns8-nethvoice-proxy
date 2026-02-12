# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For Concurrent Calls
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For Concurrent Calls
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
5 concurrent calls to single PBX complete successfully
    [Documentation]    Launch 5 simultaneous calls through the proxy to PBX-1.
    ...    Verifies Kamailio handles concurrent call setup/teardown without drops.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}
    ...    calls=5    call_rate=5    concurrent=5    duration=3000
    Verify Successful Calls    ${stat_file}    5

10 concurrent calls with media complete successfully
    [Documentation]    Launch 10 simultaneous calls with RTP media through rtpengine.
    ...    Verifies proxy and rtpengine handle moderate concurrent media load.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_call_with_media.xml    service=${PBX1_DOMAIN}
    ...    calls=10    call_rate=5    concurrent=10    duration=2000
    Verify Successful Calls    ${stat_file}    10

No rtpengine session leak after concurrent calls
    [Documentation]    After all concurrent calls end, verify no orphaned sessions.
    Verify No Active RTPEngine Sessions
