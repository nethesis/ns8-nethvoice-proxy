*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***
Input can't be empty
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {}    rc_expected=10    decode_json=False

Rule can't be empty
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {"rule":""}    rc_expected=10    decode_json=False
