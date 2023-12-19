*** Settings ***
Library   SSHLibrary
Library    Collections
Library    String
Resource  ../api.resource

*** Test Cases ***
Set an IPv4 address
    Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "1.2.3.4"}}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["addresses"]}    ${{ {"address": "1.2.3.4"} }}
   ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    1.2.3.4
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    1.2.3.4

Set an IPv4 address behind NAT
    Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "192.168.1.1", "public_address": "1.2.3.4"}}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["addresses"]}    ${{ {"address": "192.168.1.1", "public_address": "1.2.3.4"} }}
   ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    192.168.1.1
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    192.168.1.1

Set an IPv6 address
    Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "2001:db8:3333:4444:5555:6666:7777:8888"}}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["addresses"]}    ${{ {"address": "2001:db8:3333:4444:5555:6666:7777:8888"} }}
   ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    2001:db8:3333:4444:5555:6666:7777:8888
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    2001:db8:3333:4444:5555:6666:7777:8888

Add an IPv6 address behind NAT
    Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "2001:db8:3333:4444:5555:6666:7777:8888", "public_address": "2001:db8:3333:4444:CCCC:DDDD:EEEE:FFFF"}}
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}
    Should Be Equal   ${response["addresses"]}    ${{ {"address": "2001:db8:3333:4444:5555:6666:7777:8888", "public_address": "2001:db8:3333:4444:CCCC:DDDD:EEEE:FFFF"} }}
   ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "tcp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    2001:db8:3333:4444:5555:6666:7777:8888
    ${response} =  Run task    module/${module_id}/list-service-providers
    ...    {"service": "sip", "transport": "udp", "filter": {"module_id": "${module_id}"} }
    Should Be Equal    ${response[0]['host']}    2001:db8:3333:4444:5555:6666:7777:8888
