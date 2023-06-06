*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***
Input can't be empty
    ${response} =  Run task    module/${module_id}/remove-route
    ...    {}    rc_expected=10    decode_json=False

Domain is required
    ${response} =  Run task    module/${module_id}/remove-route
    ...    {"address": ["sip:127.0.0.1:5080"]}    rc_expected=10    decode_json=False

Domain can't be empty
    ${response} =  Run task    module/${module_id}/remove-route
    ...    {"domain":"", "address":["sip:127.0.0.1:5080"]}    rc_expected=10    decode_json=False
    ${response} =  Run task    module/${module_id}/add-route
    ...    {"doamin":""}    rc_expected=10    decode_json=False

Address list can't be empty
    ${response} =  Run task    module/${module_id}/remove-route
    ...    {"domain":"ns8.test", "address":[]}    rc_expected=10    decode_json=False
