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

Address and public_address in addresses configuration must be a valid address
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "A", "public_address": "B"}}    rc_expected=10    decode_json=False

Service network's configuration must present if service_network is present
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "127.0.0.1"}, "service_network": {}}    rc_expected=10    decode_json=False

Service network's address and nethmask must both be present
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "127.0.0.1"}, "service_network": {"address": "10.5.4.0.1"}}    rc_expected=10    decode_json=False
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "127.0.0.1"}, "service_network": {"nethmask": "10.5.4.0/24"}}    rc_expected=10    decode_json=False

Service network's address and nethmask must be valid
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "127.0.0.1"}, "service_network": {"address": "A", "nethmask": "10.5.4.0/24"}}    rc_expected=10    decode_json=False
    ${response} =  Run task    module/${module_id}/configure-module
    ...    {"addresses": {"address": "127.0.0.1"}, "service_network": {"address": "10.5.4.1", "nethmask": "A"}}    rc_expected=10    decode_json=False
