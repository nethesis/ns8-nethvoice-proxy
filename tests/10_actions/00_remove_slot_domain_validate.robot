*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***
Input can't be empty
    ${response} =  Run task    module/${module_id}/remove-slot-domain
    ...    {}    rc_expected=10    decode_json=False

Domain is required
    ${response} =  Run task    module/${module_id}/remove-slot-domain
    ...    {"ttl": 3600}    rc_expected=10    decode_json=False

Domain can't be empty
    ${response} =  Run task    module/${module_id}/remove-slot-domain
    ...    {"domain": ""}    rc_expected=10    decode_json=False
