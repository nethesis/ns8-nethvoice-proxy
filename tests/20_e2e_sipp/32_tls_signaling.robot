# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start PBX1 UAS For TLS Test
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 UAS For TLS Test
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
TLS signaling call completes through proxy
    [Documentation]    SIP over TLS (port 5061) through Kamailio.
    ...    Verifies TLS listener is active and handles calls.
    ...    Note: SIPp uses -t t1 for TLS transport (no cert verification).
    [Tags]    tls
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_tls_call.xml    target_port=5061    service=${PBX1_DOMAIN}
    ...    duration=3000    transport=t1    extra_args=-tls_cert /dev/null -tls_key /dev/null
    Verify Successful Calls    ${stat_file}    1
