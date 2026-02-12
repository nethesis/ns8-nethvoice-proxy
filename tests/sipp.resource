# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Shared Robot Framework keywords for SIPp-based E2E testing.
# Provides keywords to install SIPp, start/stop UAS servers,
# run UAC scenarios, parse statistics, and verify media streams.

*** Settings ***
Library    SSHLibrary
Library    String
Library    Collections
Resource   ./api.resource

*** Variables ***
# SIPp scenario files are uploaded to this directory in module home
${SIPP_SCENARIOS_DIR}        ~/sipp_scenarios
# Ports for mock PBX UAS instances (must not conflict with Kamailio 5060/5061)
${PBX1_SIP_PORT}             5080
${PBX2_SIP_PORT}             5082
# RTP media ports for SIPp (outside rtpengine range 10000-20000)
${SIPP_MEDIA_PORT_UAC}       30010
${SIPP_MEDIA_PORT_UAS1}      30020
${SIPP_MEDIA_PORT_UAS2}      30030
# Default call duration in ms
${CALL_DURATION}             3000
# SIPp timeout for calls
${SIPP_TIMEOUT}              30
# Test domains for multi-PBX routing
${PBX1_DOMAIN}               pbx1.e2etest.local
${PBX2_DOMAIN}               pbx2.e2etest.local
# Trunk patterns for multi-PBX routing
${PBX1_TRUNK_PATTERN}        1XXX
${PBX2_TRUNK_PATTERN}        2XXX

*** Keywords ***

# --- Installation & Setup ---

Install SIPp On Node
    [Documentation]    Install SIPp binary from GitHub releases in module user's home directory
    # Check if sipp is already available in module context
    ${stdout}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} sh -c 'command -v sipp || echo not_found'
    ...    return_rc=True
    ${sipp_path}=    Strip String    ${stdout}
    IF    '${sipp_path}' == 'not_found'
        Log    SIPp not found, installing from GitHub releases
        # Create bin directory in module home
        Execute Command    runagent -m ${module_id} mkdir -p ~/bin
        # Download latest SIPp binary from GitHub releases
        ${stdout}    ${rc}=    Execute Command
        ...    runagent -m ${module_id} sh -c 'curl -L -o ~/bin/sipp https://github.com/SIPp/sipp/releases/latest/download/sipp && chmod +x ~/bin/sipp'
        ...    return_rc=True    timeout=60s
        Should Be Equal As Integers    ${rc}    0    Failed to download SIPp: ${stdout}
        # Verify installation
        ${stdout}    ${rc}=    Execute Command
        ...    runagent -m ${module_id} ~/bin/sipp -v
        ...    return_rc=True
        Should Be Equal As Integers    ${rc}    0    SIPp binary is not working: ${stdout}
        Log    SIPp installed successfully: ${stdout}
    ELSE
        Log    SIPp already available at: ${sipp_path}
    END

Upload SIPp Scenarios
    [Documentation]    Upload all SIPp XML scenario files to the module home directory
    # First, get the module's home directory
    ${module_home}=    Execute Command    runagent -m ${module_id} sh -c 'echo $HOME'
    ${module_home}=    Strip String    ${module_home}
    Log    Module home directory: ${module_home}
    # Create scenarios directory in module home
    Execute Command    runagent -m ${module_id} mkdir -p ${module_home}/sipp_scenarios
    # Upload scenarios (SSHLibrary uploads to SSH session context, then we copy to module context)
    Execute Command    mkdir -p /tmp/sipp_upload_tmp
    SSHLibrary.Put Directory    ${CURDIR}/sipp_scenarios    /tmp/sipp_upload_tmp    mode=0644
    # Copy to module context
    Execute Command    runagent -m ${module_id} sh -c 'cp -r /tmp/sipp_upload_tmp/sipp_scenarios/* ${module_home}/sipp_scenarios/'
    Execute Command    rm -rf /tmp/sipp_upload_tmp
    Log    SIPp scenarios uploaded to ${module_home}/sipp_scenarios

Verify SIPp Available
    [Documentation]    Confirm SIPp is installed and working
    ${output}    ${rc}=    Execute Command    runagent -m ${module_id} ~/bin/sipp -v 2>&1 | head -1    return_rc=True
    Should Be Equal As Integers    ${rc}    0    SIPp not available on node
    Should Contain    ${output}    SIPp
    Log    SIPp version: ${output}

# --- UAS (Mock PBX) Management ---

Start UAS Server
    [Documentation]    Start a SIPp UAS server in the background
    [Arguments]    ${scenario}    ${port}    ${media_port}=${SIPP_MEDIA_PORT_UAS1}    ${extra_args}=${EMPTY}
    # Kill any existing SIPp on this port first
    Execute Command    runagent -m ${module_id} sh -c 'fuser -k ${port}/udp 2>/dev/null; fuser -k ${port}/tcp 2>/dev/null; sleep 1'    timeout=10s
    ${pid_file}=    Set Variable    /tmp/sipp_uas_${port}.pid
    ${cmd}=    Set Variable
    ...    runagent -m ${module_id} sh -c 'nohup ~/bin/sipp -sf ${SIPP_SCENARIOS_DIR}/sipp_scenarios/${scenario} -p ${port} -mi 127.0.0.1 -mp ${media_port} -rtp_echo -trace_stat -stf /tmp/sipp_uas_${port}_stat.csv -trace_err -error_file /tmp/sipp_uas_${port}_err.log -bg ${extra_args} > /tmp/sipp_uas_${port}.log 2>&1 & echo $!'
    ${pid}    ${rc}=    Execute Command    ${cmd}    return_rc=True
    Should Be Equal As Integers    ${rc}    0    Failed to start UAS on port ${port}
    ${pid}=    Strip String    ${pid}
    Execute Command    runagent -m ${module_id} sh -c 'echo ${pid} > ${pid_file}'
    # Wait for UAS to be ready
    Sleep    2s
    ${check_rc}=    Execute Command    runagent -m ${module_id} kill -0 ${pid} 2>/dev/null    return_rc=True    return_stdout=False
    Should Be Equal As Integers    ${check_rc}    0    UAS process ${pid} on port ${port} died immediately
    Log    Started UAS ${scenario} on port ${port} with PID ${pid}
    RETURN    ${pid}

Stop UAS Server
    [Documentation]    Stop a SIPp UAS server by port
    [Arguments]    ${port}
    ${pid_file}=    Set Variable    /tmp/sipp_uas_${port}.pid
    ${pid}    ${rc}=    Execute Command    runagent -m ${module_id} cat ${pid_file} 2>/dev/null    return_rc=True
    IF    ${rc} == 0
        Execute Command    runagent -m ${module_id} sh -c 'kill ${pid} 2>/dev/null; sleep 1; kill -9 ${pid} 2>/dev/null'    timeout=10s
        Execute Command    runagent -m ${module_id} rm -f ${pid_file}
    END
    # Also clean up any lingering SIPp on that port
    Execute Command    runagent -m ${module_id} sh -c 'fuser -k ${port}/udp 2>/dev/null; fuser -k ${port}/tcp 2>/dev/null'    timeout=5s

Stop All UAS Servers
    [Documentation]    Stop all known UAS servers
    Stop UAS Server    ${PBX1_SIP_PORT}
    Stop UAS Server    ${PBX2_SIP_PORT}

# --- UAC (Caller) Execution ---

Run SIPp UAC
    [Documentation]    Run a SIPp UAC scenario and return exit code + stats
    [Arguments]    ${scenario}    ${target_ip}=127.0.0.1    ${target_port}=5060
    ...    ${calls}=1    ${call_rate}=1    ${concurrent}=1    ${duration}=${CALL_DURATION}
    ...    ${service}=test    ${extra_args}=${EMPTY}    ${transport}=u1
    ${stat_file}=    Set Variable    /tmp/sipp_uac_${scenario}_stat.csv
    ${err_file}=    Set Variable    /tmp/sipp_uac_${scenario}_err.log
    ${screen_file}=    Set Variable    /tmp/sipp_uac_${scenario}_screen.log
    ${cmd}=    Set Variable
    ...    runagent -m ${module_id} ~/bin/sipp ${target_ip}:${target_port} -sf ${SIPP_SCENARIOS_DIR}/sipp_scenarios/${scenario} -s ${service} -m ${calls} -r ${call_rate} -l ${concurrent} -d ${duration} -t ${transport} -mi 127.0.0.1 -mp ${SIPP_MEDIA_PORT_UAC} -trace_stat -stf ${stat_file} -trace_err -error_file ${err_file} -timeout ${SIPP_TIMEOUT} -timeout_error ${extra_args} 2>&1
    ${stdout}    ${stderr}    ${rc}=    Execute Command    ${cmd}
    ...    return_stdout=True    return_stderr=True    return_rc=True    timeout=${${SIPP_TIMEOUT} + 30}s
    Log    SIPp UAC stdout: ${stdout}
    Log    SIPp UAC stderr: ${stderr}
    Log    SIPp UAC exit code: ${rc}
    # Read screen log if available
    ${screen_log}=    Execute Command    runagent -m ${module_id} cat ${screen_file} 2>/dev/null
    Log    SIPp screen: ${screen_log}
    RETURN    ${rc}    ${stdout}    ${stat_file}

Run SIPp UAC And Expect Success
    [Documentation]    Run a SIPp UAC scenario and assert it succeeds (exit code 0)
    [Arguments]    ${scenario}    ${target_ip}=127.0.0.1    ${target_port}=5060
    ...    ${calls}=1    ${call_rate}=1    ${concurrent}=1    ${duration}=${CALL_DURATION}
    ...    ${service}=test    ${extra_args}=${EMPTY}    ${transport}=u1
    ${rc}    ${stdout}    ${stat_file}=    Run SIPp UAC    ${scenario}
    ...    target_ip=${target_ip}    target_port=${target_port}
    ...    calls=${calls}    call_rate=${call_rate}    concurrent=${concurrent}
    ...    duration=${duration}    service=${service}    extra_args=${extra_args}    transport=${transport}
    Should Be Equal As Integers    ${rc}    0
    ...    SIPp UAC scenario ${scenario} failed with rc=${rc}${\n}Output: ${stdout}
    RETURN    ${stat_file}

Run SIPp UAC And Expect Failure
    [Documentation]    Run a SIPp UAC scenario and assert it fails (non-zero exit code)
    [Arguments]    ${scenario}    ${target_ip}=127.0.0.1    ${target_port}=5060
    ...    ${calls}=1    ${service}=test    ${extra_args}=${EMPTY}    ${transport}=u1
    ${rc}    ${stdout}    ${stat_file}=    Run SIPp UAC    ${scenario}
    ...    target_ip=${target_ip}    target_port=${target_port}
    ...    calls=${calls}    service=${service}    extra_args=${extra_args}    transport=${transport}
    Should Not Be Equal As Integers    ${rc}    0
    ...    SIPp UAC scenario ${scenario} was expected to fail but succeeded
    RETURN    ${rc}    ${stat_file}

# --- Statistics & Verification ---

Get SIPp Stats
    [Documentation]    Parse SIPp CSV statistics file and return key metrics
    [Arguments]    ${stat_file}
    ${output}    ${rc}=    Execute Command    runagent -m ${module_id} tail -1 ${stat_file} 2>/dev/null    return_rc=True
    IF    ${rc} != 0 or len($output.strip()) == 0
        Log    No stats available from ${stat_file}
        RETURN    ${EMPTY}
    END
    Log    SIPp stats (last line): ${output}
    RETURN    ${output}

Verify Successful Calls
    [Documentation]    Verify SIPp UAC completed expected number of successful calls
    [Arguments]    ${stat_file}    ${expected_calls}
    ${stats}=    Get SIPp Stats    ${stat_file}
    Should Not Be Empty    ${stats}    No SIPp statistics found in ${stat_file}
    # SIPp CSV format: column 3 = SuccessfulCall(C)
    ${fields}=    Split String    ${stats}    ;
    ${successful}=    Strip String    ${fields}[3]
    Should Be Equal As Integers    ${successful}    ${expected_calls}
    ...    Expected ${expected_calls} successful calls, got ${successful}

# --- Route/Trunk Configuration ---

Setup PBX Route
    [Documentation]    Create a domain route pointing to a SIPp UAS
    [Arguments]    ${domain}    ${port}    ${description}=e2e-test-pbx
    Run Task    module/${module_id}/add-route
    ...    {"domain":"${domain}", "address":[{"uri":"sip:127.0.0.1:${port}","description":"${description}"}]}

Setup PBX Trunk
    [Documentation]    Create a trunk rule pointing to a SIPp UAS
    [Arguments]    ${rule}    ${port}    ${description}=e2e-test-pbx
    Run Task    module/${module_id}/add-trunk
    ...    {"rule":"${rule}", "destination":{"uri":"sip:127.0.0.1:${port}","description":"${description}"}}

Cleanup PBX Route
    [Documentation]    Remove a domain route
    [Arguments]    ${domain}
    Run Task    module/${module_id}/remove-route    {"domain":"${domain}"}

Cleanup PBX Trunk
    [Documentation]    Remove a trunk rule
    [Arguments]    ${rule}
    Run Task    module/${module_id}/remove-trunk    {"rule":"${rule}"}

Setup Single PBX
    [Documentation]    Set up PBX-1 route and start its UAS server
    Setup PBX Route    ${PBX1_DOMAIN}    ${PBX1_SIP_PORT}    e2e-pbx1
    ${pid}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    Set Suite Variable    ${UAS1_PID}    ${pid}

Teardown Single PBX
    [Documentation]    Stop PBX-1 UAS and remove its route
    Stop UAS Server    ${PBX1_SIP_PORT}
    Cleanup PBX Route    ${PBX1_DOMAIN}

Setup Dual PBX
    [Documentation]    Set up PBX-1 and PBX-2 routes and start both UAS servers
    Setup PBX Route    ${PBX1_DOMAIN}    ${PBX1_SIP_PORT}    e2e-pbx1
    Setup PBX Route    ${PBX2_DOMAIN}    ${PBX2_SIP_PORT}    e2e-pbx2
    ${pid1}=    Start UAS Server    uas_answer.xml    ${PBX1_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS1}
    ${pid2}=    Start UAS Server    uas_answer.xml    ${PBX2_SIP_PORT}    ${SIPP_MEDIA_PORT_UAS2}
    Set Suite Variable    ${UAS1_PID}    ${pid1}
    Set Suite Variable    ${UAS2_PID}    ${pid2}

Teardown Dual PBX
    [Documentation]    Stop both UAS servers and remove routes
    Stop All UAS Servers
    Cleanup PBX Route    ${PBX1_DOMAIN}
    Cleanup PBX Route    ${PBX2_DOMAIN}

# --- Media/RTPEngine Verification ---

Get RTPEngine Session Count
    [Documentation]    Get the number of active rtpengine sessions
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec rtpengine rtpengine-ctl list sessions | grep -c "session" || echo 0
    ...    return_rc=True
    ${count}=    Strip String    ${output}
    ${count}=    Convert To Integer    ${count}
    RETURN    ${count}

Verify No Active RTPEngine Sessions
    [Documentation]    Assert that rtpengine has no active media sessions (no leaks)
    Sleep    2s    Wait for sessions to clean up
    ${count}=    Get RTPEngine Session Count
    Should Be Equal As Integers    ${count}    0
    ...    Expected 0 active rtpengine sessions but found ${count} (media leak!)

Get RTPEngine Stats
    [Documentation]    Get rtpengine statistics summary
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} podman exec rtpengine rtpengine-ctl list totals
    ...    return_rc=True
    Log    RTPEngine stats: ${output}
    RETURN    ${output}

# --- Cleanup ---

Cleanup SIPp Artifacts
    [Documentation]    Remove all SIPp temporary files from the node
    Execute Command    runagent -m ${module_id} rm -rf ${SIPP_SCENARIOS_DIR} /tmp/sipp_ua*.csv /tmp/sipp_ua*.log /tmp/sipp_ua*.pid
