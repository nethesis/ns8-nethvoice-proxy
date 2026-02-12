# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later

*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource

*** Test Cases ***
Install SIPp on the node
    [Documentation]    Ensure SIPp is installed and available
    Install SIPp On Node

Upload SIPp scenario files
    [Documentation]    Copy all SIPp XML scenarios to the NS8 node
    Upload SIPp Scenarios

Verify uploaded scenarios are readable
    [Documentation]    Check that uploaded scenario files are intact on the node
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} sh -c 'ls -la $HOME/sipp_scenarios/ && echo "---" && file $HOME/sipp_scenarios/uas_answer.xml && echo "---" && head -3 $HOME/sipp_scenarios/uas_answer.xml && echo "---" && xxd $HOME/sipp_scenarios/uas_answer.xml | head -3'
    ...    return_rc=True
    Log    Scenario file diagnostics: ${output}
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    uas_answer.xml

Verify SIPp can parse a minimal scenario
    [Documentation]    Create and parse a minimal inline scenario to confirm SIPp works
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} sh -c 'echo '"'"'<?xml version="1.0" encoding="UTF-8"?><scenario name="test"><recv request="INVITE" crlf="true"/></scenario>'"'"' > /tmp/sipp_test_parse.xml && $HOME/bin/sipp -sf /tmp/sipp_test_parse.xml -p 19999 -bg 2>&1; echo "EXIT:$?"; rm -f /tmp/sipp_test_parse.xml'
    ...    return_rc=True
    Log    SIPp minimal parse test: ${output}
    # SIPp with -bg should output a PID if parsing succeeds
    Should Not Contain    ${output}    Unable to load or parse    SIPp cannot parse even a minimal scenario — binary may be broken

Verify SIPp can parse uploaded scenario
    [Documentation]    Confirm SIPp can parse the actual uas_answer.xml scenario
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} sh -c '$HOME/bin/sipp -sf $HOME/sipp_scenarios/uas_answer.xml -p 19998 -bg 2>&1; RET=$?; kill $(cat /tmp/sipp_19998_*.pid 2>/dev/null) 2>/dev/null; echo "EXIT:$RET"'
    ...    return_rc=True
    Log    SIPp parse uas_answer test: ${output}
    Should Not Contain    ${output}    Unable to load or parse    SIPp cannot parse uas_answer.xml: ${output}

Verify SIPp is working
    [Documentation]    Confirm SIPp binary is functional
    Verify SIPp Available

Verify Kamailio is responding
    [Documentation]    Confirm Kamailio is up before running call tests
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio kamcmd core.uptime
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    uptime

Verify rtpengine is responding
    [Documentation]    Confirm rtpengine is up before running media tests
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec rtpengine rtpengine-ctl list totals
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0

Configure PBX-1 route for e2e tests
    [Documentation]    Create domain route for PBX-1 pointing to SIPp UAS port
    Setup PBX Route    ${PBX1_DOMAIN}    ${PBX1_SIP_PORT}    e2e-pbx1
    ${response}=    Run Task    module/${module_id}/get-route    {"domain":"${PBX1_DOMAIN}"}
    Should Not Be Empty    ${response}
