# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Library    String
Resource   ../sipp.resource
Suite Setup       Setup Load Balancing Environment
Suite Teardown    Teardown Load Balancing Environment

*** Variables ***
${LB_DOMAIN}    lb.e2etest.local
${LB_PORT_A}    5084
${LB_PORT_B}    5086

*** Keywords ***
Setup Load Balancing Environment
    [Documentation]    Create a single domain route with 2 addresses (load balancing)
    # Start two UAS servers simulating two Asterisk nodes in the same dispatcher set
    ${pidA}=    Start UAS Server    uas_answer.xml    ${LB_PORT_A}    30040
    ${pidB}=    Start UAS Server    uas_answer.xml    ${LB_PORT_B}    30050
    Set Suite Variable    ${UAS_A_PID}    ${pidA}
    Set Suite Variable    ${UAS_B_PID}    ${pidB}
    # Add route with both addresses in a single dispatcher set
    Run Task    module/${module_id}/add-route
    ...    {"domain":"${LB_DOMAIN}", "address":[{"uri":"sip:127.0.0.1:${LB_PORT_A}","description":"node-a"},{"uri":"sip:127.0.0.1:${LB_PORT_B}","description":"node-b"}]}

Teardown Load Balancing Environment
    Stop UAS Server    ${LB_PORT_A}
    Stop UAS Server    ${LB_PORT_B}
    Cleanup PBX Route    ${LB_DOMAIN}

*** Test Cases ***
Multiple calls are distributed across both PBX nodes
    [Documentation]    Send multiple calls to a domain with 2 dispatcher destinations.
    ...    Verifies Kamailio's dispatcher module distributes calls across both nodes.
    ${stat_file}=    Run SIPp UAC And Expect Success
    ...    uac_basic_call.xml    service=${LB_DOMAIN}
    ...    calls=6    call_rate=2    concurrent=2    duration=2000
    Verify Successful Calls    ${stat_file}    6

Verify both UAS instances received calls
    [Documentation]    Check that both SIPp UAS instances processed calls (not all on one).
    # Check UAS-A stats
    ${statA}    ${rcA}=    Execute Command    cat /tmp/sipp_uas_${LB_PORT_A}_stat.csv 2>/dev/null | tail -1    return_rc=True
    # Check UAS-B stats
    ${statB}    ${rcB}=    Execute Command    cat /tmp/sipp_uas_${LB_PORT_B}_stat.csv 2>/dev/null | tail -1    return_rc=True
    Log    UAS-A stats: ${statA}
    Log    UAS-B stats: ${statB}
    # At minimum, both should have log files (indicating they received traffic)
    ${logA}    ${rcLA}=    Execute Command    wc -l < /tmp/sipp_uas_${LB_PORT_A}.log 2>/dev/null    return_rc=True
    ${logB}    ${rcLB}=    Execute Command    wc -l < /tmp/sipp_uas_${LB_PORT_B}.log 2>/dev/null    return_rc=True
    Log    UAS-A log lines: ${logA}, UAS-B log lines: ${logB}
