*** Settings ***
Resource    ../api.resource

*** Test Cases ***

Configure module with local_source_subnets
    ${addresses}=    Create Dictionary    address=192.168.100.10    public_address=88.88.88.1
    ${service_network}=    Create Dictionary    address=10.5.4.1    netmask=10.5.4.0/24
    ${local_source_subnets}=    Create List    192.168.100.0/24    10.10.0.0/16
    ${local_networks}=    Create List    192.168.100.0/24
    ${payload}=    Create Dictionary
    ...    fqdn=proxy.test.local
    ...    lets_encrypt=${False}
    ...    addresses=${addresses}
    ...    service_network=${service_network}
    ...    local_source_subnets=${local_source_subnets}
    ...    local_networks=${local_networks}
    
    ${response}=    Run task    module/${module_id}/configure-module    ${payload}
    
    Should Be Equal As Strings    ${response["exit_code"]}    0

Get configuration with local_source_subnets
    ${response}=    Run task    module/${module_id}/get-configuration    {}
    
    Should Be Equal As Strings    ${response["exit_code"]}    0
    
    ${output}=    Set Variable    ${response["output"]}
    
    # Verify local_source_subnets is present and correct
    Should Contain    ${output}    local_source_subnets
    ${local_source_subnets}=    Set Variable    ${output["local_source_subnets"]}
    Should Contain    ${local_source_subnets}    192.168.100.0/24
    Should Contain    ${local_source_subnets}    10.10.0.0/16

Configure module without local_source_subnets
    ${addresses}=    Create Dictionary    address=192.168.100.10    public_address=88.88.88.1
    ${service_network}=    Create Dictionary    address=10.5.4.1    netmask=10.5.4.0/24
    ${payload}=    Create Dictionary
    ...    fqdn=proxy.test.local
    ...    lets_encrypt=${False}
    ...    addresses=${addresses}
    ...    service_network=${service_network}
    
    ${response}=    Run task    module/${module_id}/configure-module    ${payload}
    
    Should Be Equal As Strings    ${response["exit_code"]}    0
    
    # Verify module still works without local_source_subnets
    ${response}=    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal As Strings    ${response["exit_code"]}    0

