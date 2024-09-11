*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***
Get default configuration
    ${response} =  Run task    module/${module_id}/get-configuration
    ...    {}    rc_expected=0
