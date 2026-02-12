# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Library    String
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For NAT Test
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For NAT Test
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
Call with rport parameter handled correctly
    [Documentation]    SIPp sends Via with rport, simulating a NAT'd endpoint.
    ...    Verifies Kamailio's NATDETECT route processes rport and adds contact alias.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}    duration=2000
    Verify Successful Calls    ${stat_file}    1

Call with media behind simulated NAT
    [Documentation]    RTP media from a different IP than SIP signaling (simulated via loopback).
    ...    Verifies rtpengine handles asymmetric NAT media correctly.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_call_with_media.xml    service=${PBX1_DOMAIN}    duration=2000
    Verify Successful Calls    ${stat_file}    1
    Verify No Active RTPEngine Sessions
