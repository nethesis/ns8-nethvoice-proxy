*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***

FQDN cannot be empty
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"fqdn": ""}    rc_expected=10    decode_json=False

FQDN must be a valid domain name
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"fqdn": "example@#$"}    rc_expected=10    decode_json=False

Address in addresses configuration is required
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"public_address": "127.0.0.1"}}    rc_expected=10    decode_json=False

Address and public_address in addresses configuration must be a valid IPV4/IPV6 address
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "A", "public_address": "B"}}    rc_expected=10    decode_json=False
