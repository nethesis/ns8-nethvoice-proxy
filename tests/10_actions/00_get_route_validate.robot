*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***
Input can't be empty
    ${response} =  Run task    module/${module_id}/get-route
    ...    {}    rc_expected=10    decode_json=False

Domain can't be empty
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":""}    rc_expected=10    decode_json=False
