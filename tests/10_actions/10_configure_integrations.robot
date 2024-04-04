*** Settings ***
Library   SSHLibrary
Library    Collections
Library    String
Resource  ../api.resource

*** Test Cases ***
Set an address
    Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "${local_ip}"}}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["addresses"]}    ${{ {"address": "${local_ip}"} }}
   ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['address']}    ${local_ip}
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['address']}    ${local_ip}

Set an address behind NAT
    Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "${local_ip}", "public_address": "1.2.3.4"}}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["addresses"]}    ${{ {"address": "${local_ip}", "public_address": "1.2.3.4"} }}
   ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['address']}    ${local_ip}
    Should Be Equal    ${response[0]['public_address']}    1.2.3.4
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['address']}    ${local_ip}
    Should Be Equal    ${response[0]['public_address']}    1.2.3.4

Set FQDN to a valid value
    Run task    module/${module_id}/configure-module
    ...    {"fqdn": "example.com"}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["fqdn"]}    example.com
