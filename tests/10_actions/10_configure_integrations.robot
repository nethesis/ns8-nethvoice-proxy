*** Settings ***
Library   SSHLibrary
Library    Collections
Library    String
Resource  ../api.resource

*** Test Cases ***
Set a FQDN without let's encrypt and address an without NAT
    Run task    module/${module_id}/configure-module
    ...    {"fqdn": "example.com", "lets_encrypt": false, "addresses": {"address": "${local_ip}"}}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["fqdn"]}    example.com
    Should Be Equal   ${response["addresses"]}    ${{ {"address": "${local_ip}"} }}
    Should Be Empty   ${response['local_networks']}
   ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['address']}    ${local_ip}
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['address']}    ${local_ip}
    ${firewall_ports}  ${rc} =    Execute Command    firewall-cmd --permanent --service=${module_id} --get-ports
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${firewall_ports}    5060-5061/tcp
    Should Contain    ${firewall_ports}    5060/udp
    Should Contain    ${firewall_ports}    10000-20000/udp
    Should Not Contain    ${firewall_ports}    5061/udp
    Should Not Contain    ${firewall_ports}    6060/udp
    Should Not Contain    ${firewall_ports}    6060-6061/tcp

Set a FQDN without let's encrypt and an address with NAT
    Run task    module/${module_id}/configure-module
    ...    {"fqdn": "example.com", "lets_encrypt": false, "addresses": {"address": "${local_ip}", "public_address": "1.2.3.4"}, "local_networks": ["10.20.30.0/24"]}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["addresses"]}    ${{ {"address": "${local_ip}", "public_address": "1.2.3.4"} }}
    Should Contain Match   ${response['local_networks']}   ${local_network}
    Should Contain Match   ${response['local_networks']}   10.20.30.0/24
   ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['address']}    ${local_ip}
    Should Be Equal    ${response[0]['public_address']}    1.2.3.4
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['address']}    ${local_ip}
    Should Be Equal    ${response[0]['public_address']}    1.2.3.4
    ${firewall_ports}  ${rc} =    Execute Command    firewall-cmd --permanent --service=${module_id} --get-ports
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${firewall_ports}    5060-5061/tcp
    Should Contain    ${firewall_ports}    5060/udp
    Should Contain    ${firewall_ports}    10000-20000/udp
    Should Contain    ${firewall_ports}    6060-6061/tcp
    Should Contain    ${firewall_ports}    6060/udp
    Should Not Contain    ${firewall_ports}    5061/udp
    Should Not Contain    ${firewall_ports}    6061/udp
