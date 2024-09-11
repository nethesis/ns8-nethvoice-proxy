*** Settings ***
Library   SSHLibrary
Library    Collections
Library    String
Resource  ../api.resource

*** Test Cases ***
Add a new trunk
    Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551594XX", "destination":{"uri":"sip:127.0.0.1:5080","description":"module1"}}
    Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551595XX", "destination":{"uri":"sip:127.0.0.1:5081","description":"module2"}}

Get info about a non-existing trunk
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {"rule":"05551596XX"}
    Should Be Empty    ${response}

Get info about a trunk
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {"rule":"05551594XX"}
    Should Be Equal    ${response["destination"]}    ${{ {"uri":"sip:127.0.0.1:5080","description":"module1"} }}
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {"rule":"05551595XX"}
    Should be Equal    ${response["destination"]}    ${{ {"uri":"sip:127.0.0.1:5081","description":"module2"} }}

Rewrite a trunk
    Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551594XX", "destination":{"uri":"sip:127.0.0.1:5060","description":"module3"}}
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {"rule":"05551594XX"}
    Should Be Equal    ${response["destination"]}    ${{ {"uri":"sip:127.0.0.1:5060","description":"module3"} }}
    Run task    module/${module_id}/add-trunk
    ...    {"rule":"05551595XX", "destination":{"uri":"sip:127.0.0.1:5084","description":"module4"}}
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {"rule":"05551595XX"}
    Should Be Equal    ${response["destination"]}    ${{ {"uri":"sip:127.0.0.1:5084","description":"module4"} }}

Get list of trunks
    ${response} =  Run task    module/${module_id}/list-trunks    {}
    ${list_len} =  Get Length    ${response}
    Should Be Equal As Numbers    2    ${list_len}

Remove a not existing trunk
    ${response} =  Run task    module/${module_id}/remove-trunk
    ...    {"rule":"05551596XX"}
    Should Be Empty    ${response}

Remove a trunk
    Run task    module/${module_id}/remove-trunk
    ...    {"rule":"05551594XX"}
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {"rule":"05551594XX"}
    Should Be Empty    ${response}
    Run task    module/${module_id}/remove-trunk
    ...    {"rule":"05551595XX"}
    ${response} =  Run task    module/${module_id}/get-trunk
    ...    {"rule":"05551595XX"}
    Should Be Empty    ${response}


List of trunks should be empty
    ${response} =  Run task    module/${module_id}/list-trunks    {}
    Should Be Empty    ${response}
