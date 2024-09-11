*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***
Input can't be empty
    ${response} =  Run task    module/${module_id}/remove-trunk
    ...    {}    rc_expected=10    decode_json=False

Rule is required
    ${response} =  Run task    module/${module_id}/remove-trunk
    ...    {"destination": {"uri": "sip:127.0.0.1:5080", "description": "module1"}}    rc_expected=10    decode_json=False

Rule can't be empty
    ${response} =  Run task    module/${module_id}/remove-trunk
    ...    {"rule":""}    rc_expected=10    decode_json=False
