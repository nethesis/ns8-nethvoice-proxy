*** Settings ***
Library    SSHLibrary
Resource   ../sipp.resource

*** Keywords ***
Connect and prepare SIPp
    Open Connection    ${NODE_ADDR}
    Login With Public Key    root    ${SSH_KEYFILE}
    ${output}=    Execute Command    systemctl is-system-running --wait
    Should Be True    '${output}' == 'running' or '${output}' == 'degraded'

*** Settings ***
Suite Setup       Connect and prepare SIPp
Suite Teardown    Stop All UAS Servers
