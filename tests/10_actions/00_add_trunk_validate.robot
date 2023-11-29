*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***
Input can't be empty
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {}    rc_expected=10    decode_json=False

Rule is required
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {"destination": {"uri": "sip:127.0.0.1:5080", "description": "module1"}}    rc_expected=10    decode_json=False

Destination is required
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {"rule": "05551594XX"}    rc_expected=10    decode_json=False

Rule can't be empty
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {"rule":"", "destination":{"uri": "sip:127.0.0.1:5080", "description": "module1"}}    rc_expected=10    decode_json=False

Destination can't be empty
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551594XX", "destination":{}}    rc_expected=10    decode_json=False

URI field is required
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551594XX", "destination":{"description": "module1"}}    rc_expected=10    decode_json=False

URI field can't be empty
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551594XX", "destination":{"uri": "", "description": "module1"}}    rc_expected=10    decode_json=False

Description field is required
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551594XX", "destination":{"uri": "sip:127.0.0.1:5080"}}    rc_expected=10    decode_json=False

Description field can't be empty
    ${response} =  Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551594XX", "destination":{"uri": "sip:127.0.0.1:5080", "description": ""}}    rc_expected=10    decode_json=False

