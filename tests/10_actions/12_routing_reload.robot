*** Settings ***
Library    SSHLibrary
Library    Process
Resource    ../api.resource
Suite Teardown    Remove reload test routes

*** Test Cases ***
Check reload error handling and locking
    ${result} =    Run Process    python3    -m    unittest    discover    -s    ${CURDIR}/../unit
    Should Be Equal As Integers    ${result.rc}    0    ${result.stderr}

Rapid trunk updates reach the live dispatcher
    Run task    module/${module_id}/add-trunk
    ...    {"rule":"reload-regression-test","destination":{"uri":"sip:127.0.0.1:34991","description":"reload test"}}
    Run task    module/${module_id}/add-trunk
    ...    {"rule":"reload-regression-test","destination":{"uri":"sip:127.0.0.1:34992","description":"reload test"}}
    ${trunk} =    Run task    module/${module_id}/get-trunk    {"rule":"reload-regression-test"}
    Should Be Equal    ${trunk}[destination][uri]    sip:127.0.0.1:34992
    Dispatcher should contain only new destination
    ...    sip:127.0.0.1:34992    sip:127.0.0.1:34991
    Run task    module/${module_id}/remove-trunk    {"rule":"reload-regression-test"}
    Dispatcher should not contain    sip:127.0.0.1:34992

Rapid domain updates and removal reach the live dispatcher
    Run task    module/${module_id}/add-route
    ...    {"domain":"reload-regression.invalid","address":[{"uri":"sip:127.0.0.1:34993","description":"reload test"}]}
    Run task    module/${module_id}/add-route
    ...    {"domain":"reload-regression.invalid","address":[{"uri":"sip:127.0.0.1:34994","description":"reload test"}]}
    Dispatcher should contain only new destination
    ...    sip:127.0.0.1:34994    sip:127.0.0.1:34993
    Run task    module/${module_id}/remove-route    {"domain":"reload-regression.invalid"}
    Dispatcher should not contain    sip:127.0.0.1:34994

*** Keywords ***
Read live dispatcher
    ${stdout}    ${stderr}    ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio kamcmd dispatcher.list
    ...    return_stdout=True    return_stderr=True    return_rc=True
    Should Be Equal As Integers    ${rc}    0    ${stderr}
    Should Not Contain    ${stdout}    error:
    RETURN    ${stdout}

Dispatcher should contain only new destination
    [Arguments]    ${new}    ${old}
    ${dispatcher} =    Read live dispatcher
    Should Contain    ${dispatcher}    ${new}
    Should Not Contain    ${dispatcher}    ${old}

Dispatcher should not contain
    [Arguments]    ${uri}
    ${dispatcher} =    Read live dispatcher
    Should Not Contain    ${dispatcher}    ${uri}

Remove reload test routes
    Run Keyword And Continue On Failure    Run task
    ...    module/${module_id}/remove-trunk    {"rule":"reload-regression-test"}
    Run Keyword And Continue On Failure    Run task
    ...    module/${module_id}/remove-route    {"domain":"reload-regression.invalid"}
