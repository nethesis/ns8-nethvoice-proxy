*** Settings ***
Library   SSHLibrary

*** Test Cases ***
Check rtpengine container is running
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman ps --filter name=rtpengine --format "{{.Status}}"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    Up

Check rtpengine control socket is accessible
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman exec rtpengine rtpengine-ctl list
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0

Check kamailio container is running
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman ps --filter name=kamailio --format "{{.Status}}"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    Up

Check kamailio is responding
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd core.uptime
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    uptime

Check postgres container is running
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman ps --filter name=postgres --format "{{.Status}}"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    Up

Check postgres is accepting connections
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman exec postgres pg_isready -U postgres
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    accepting connections

Check redis container is running
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman ps --filter name=redis --format "{{.Status}}"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    Up

Check redis is responding
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman exec redis redis-cli ping
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    PONG
