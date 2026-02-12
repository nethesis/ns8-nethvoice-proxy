# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource
Suite Setup       Setup Failover Environment
Suite Teardown    Teardown Failover Environment

*** Variables ***
${FO_DOMAIN}     fo.e2etest.local
${FO_PORT_PRI}   5088
${FO_PORT_SEC}   5090

*** Keywords ***
Setup Failover Environment
    [Documentation]    Create a domain with 2 addresses; start only the secondary UAS
    # Start only secondary UAS (primary will be "down")
    ${pidSec}=    Start UAS Server    uas_answer.xml    ${FO_PORT_SEC}    30060
    Set Suite Variable    ${UAS_SEC_PID}    ${pidSec}
    # Configure route with both primary and secondary addresses
    Run Task    module/${module_id}/add-route
    ...    {"domain":"${FO_DOMAIN}", "address":[{"uri":"sip:127.0.0.1:${FO_PORT_PRI}","description":"primary"},{"uri":"sip:127.0.0.1:${FO_PORT_SEC}","description":"secondary"}]}

Teardown Failover Environment
    Stop UAS Server    ${FO_PORT_PRI}
    Stop UAS Server    ${FO_PORT_SEC}
    Cleanup PBX Route    ${FO_DOMAIN}

*** Test Cases ***
Call fails over to secondary when primary is down
    [Documentation]    Primary PBX (port ${FO_PORT_PRI}) is not running.
    ...    Kamailio's dispatcher should detect the failure and route to secondary (port ${FO_PORT_SEC}).
    ...    Verifies the dispatcher failover/probing mechanism.
    [Tags]    failover
    # Allow time for dispatcher to probe and detect primary as down
    Sleep    5s    Wait for dispatcher probing cycle
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${FO_DOMAIN}    duration=2000
    ...    extra_args=-timeout 15
    Verify Successful Calls    ${stat_file}    1

Multiple calls succeed with primary down
    [Documentation]    Send multiple calls — all should route to secondary via failover.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${FO_DOMAIN}
    ...    calls=3    call_rate=1    duration=2000    extra_args=-timeout 15
    Verify Successful Calls    ${stat_file}    3
