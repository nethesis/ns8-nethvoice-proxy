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

Gather system information
    ${response}=    Run Task    module/${module_id}/get-available-interfaces   {}
    FOR    ${interface}    IN    @{response['data']}
        ${address}=    Set Variable    ${interface['addresses'][0]['address']}
        EXIT FOR LOOP IF    "${interface['name']}" == "wg0"
    END
    Set Global Variable    ${service_ip}    ${address}

    FOR    ${interface}    IN    @{response['data']}
        ${address}=    Set Variable    ${interface['addresses'][0]['address']}
        EXIT FOR LOOP IF    "${interface['name']}" == "eth0"
    END
    Set Global Variable    ${local_ip}    ${address}

Check if nethvoice-proxy is configured wih the correctly default values
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"}}
    Should Be Equal    ${response[0]['host']}    ${service_ip}
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    ${service_ip}
