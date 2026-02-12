# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Start PBX1 Busy UAS
Suite Teardown    Stop UAS Server    ${PBX1_SIP_PORT}

*** Keywords ***
Start PBX1 Busy UAS
    # Use busy UAS that responds 486 to all INVITEs
    ${pid}=    Start UAS Server    uas_busy.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

*** Test Cases ***
Call to busy PBX propagates 486 Busy Here
    [Documentation]    INVITE to a busy PBX endpoint.
    ...    Verifies 486 Busy Here is propagated back through the proxy to the UAC.
    ...    SIPp UAC receives a non-2xx response so it returns non-zero exit code.
    ${rc}    ${stat_file}=    Run SIPp UAC And Expect Failure
    ...    uac_basic_call.xml    service=${PBX1_DOMAIN}
    Log    Expected failure with rc=${rc} (486 Busy Here from UAS)
