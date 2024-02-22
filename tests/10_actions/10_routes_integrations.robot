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
    ...    {"domain":"ns8.test", "address":[{"uri":"sip:127.0.0.1:5080","description":"module1"},{"uri":"sip:127.0.0.1:5081","description":"module2"}]}
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test"}
    Length Should Be    ${response["address"]}    2
    Should Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5080","description":"module1"} }}
    Should Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5081","description":"module2"} }}

Remove an addres from an existing route
    Run task    module/${module_id}/add-route
    ...    {"domain":"ns8.test", "address":[{"uri":"sip:127.0.0.1:5080","description":"module1"}]}
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test"}
    Length Should Be    ${response["address"]}    1
    Should Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5080","description":"module1"} }}
    Should Not Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5081","description":"module2"} }}

Ovveride an existing route
     Run task    module/${module_id}/add-route
    ...    {"domain":"ns8.test", "address":[{"uri":"sip:127.0.0.1:5082","description":"module3"}]}
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test"}
    Length Should Be    ${response["address"]}    1
    Should Contain    ${response["address"]}    ${{ {"uri":"sip:127.0.0.1:5082","description":"module3"} }}

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
    Length Should Be     ${response}    2

Get info about a route
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test"}
    Should Be Equal    ${response}    ${{ {"address":[{"uri":"sip:127.0.0.1:5080","description":"module1"}]} }}
    ${response} =  Run task    module/${module_id}/get-route
    ...    {"domain":"ns8.test1"}
    Should Be Equal    ${response}    ${{ {"address":[{"uri":"sip:127.0.0.1:5081","description":"module2"}]} }}

List of routes should be empty
    Run task    module/${module_id}/remove-route
    ...    {"domain":"ns8.test"}
    Run task    module/${module_id}/remove-route
    ...    {"domain":"ns8.test1"}
    ${response} =  Run task    module/${module_id}/list-routes    {}
    Should Be Empty    ${response}
