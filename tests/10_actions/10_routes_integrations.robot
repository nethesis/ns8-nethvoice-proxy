*** Settings ***
Library   SSHLibrary
Library    Collections
Library    String
Resource  ../api.resource

*** Test Cases ***
Add a new route
    Run task    module/${module_id}/add-route
    ...    {"domain":"ns8.test", "address":[{"uri":"sip:127.0.0.1:5080","description":"module1"}]}
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test"}
    Should Be Equal    ${response["address"]}    ${{ [{"uri":"sip:127.0.0.1:5080","description":"module1"}] }}

Add a new addres to an existing route
    Run task    module/${module_id}/add-route
    ...    {"domain":"ns8.test", "address":[{"uri":"sip:127.0.0.1:5081","description":"module2"}]}
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test"}
    Should Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5080","description":"module1"} }}
    Should Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5081","description":"module2"} }}

Remove an addres from an existing route
    Run task    module/${module_id}/remove-route
    ...    {"domain":"ns8.test", "address":[{"uri":"sip:127.0.0.1:5081","description":"module2"}]}
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test"}
    Should Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5080","description":"module1"} }}
    Should Not Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5081","description":"module2"} }}

Remove a route
    Run task    module/${module_id}/remove-route
    ...    {"domain":"ns8.test"}
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test"}
    Should Be Empty    ${response}

Get list of routes
    Run task    module/${module_id}/add-route
    ...    {"domain":"ns8.test", "address":[{"uri":"sip:127.0.0.1:5080","description":"module1"}]}
    Run task    module/${module_id}/add-route
    ...    {"domain":"ns8.test1", "address":[{"uri":"sip:127.0.0.1:5081","description":"module2"}]}
    ${response} =  Run task    module/${module_id}/list-routes    {}
    ${list_len} =  Get Length    ${response}
    Should Be Equal As Numbers    2    ${list_len}

List of routes should be empty
    Run task    module/${module_id}/remove-route
    ...    {"domain":"ns8.test"}
    Run task    module/${module_id}/remove-route
    ...    {"domain":"ns8.test1"}
    ${response} =  Run task    module/${module_id}/list-routes    {}
    Should Be Empty    ${response}

