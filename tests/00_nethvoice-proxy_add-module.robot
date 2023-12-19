*** Settings ***
Library    SSHLibrary
Resource    ./api.resource

*** Test Cases ***
Check if nethvoice-proxy is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"}}
    Should Be Equal    ${response[0]['host']}    127.0.0.1
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    127.0.0.1
