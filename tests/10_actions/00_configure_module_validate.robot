*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***

Address in addresses configuration is required
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"pubblic_address": "127.0.0.1"}}    rc_expected=10    decode_json=False

Address and pubblic_address in addresses configuration must be a valid IPV4/IPV6 address
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "A", "pubblic_address": "B"}}    rc_expected=10    decode_json=False
