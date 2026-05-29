*** Settings ***
Resource    api.resource
Resource    ui.resource
Suite Teardown    Run Keyword And Ignore Error    Close Browser

*** Test Cases ***
Preserve local networks after saving settings
    [Tags]    ui
    Run task    module/${module_id}/configure-module
    ...    {"fqdn": "before.example.com", "lets_encrypt": false, "addresses": {"address": "${local_ip}", "public_address": "1.2.3.4"}, "local_networks": ["10.20.30.0/24"]}
    ${before} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${before["fqdn"]}    before.example.com
    Should Be Equal
    ...    ${before["addresses"]}
    ...    ${{ {"address": "${local_ip}", "public_address": "1.2.3.4"} }}
    Should Contain    ${before["local_networks"]}    ${local_network}
    Should Contain    ${before["local_networks"]}    10.20.30.0/24

    Open Browser To Cluster Admin    ${NODE_ADDR}
    Open App Settings Page    ${NODE_ADDR}    ${module_id}
    Save Settings Form
    Assert No Settings Errors

    ${after} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${after["fqdn"]}    before.example.com
    Should Be Equal
    ...    ${after["addresses"]}
    ...    ${{ {"address": "${local_ip}", "public_address": "1.2.3.4"} }}
    Should Contain    ${after["local_networks"]}    ${local_network}
    Should Contain    ${after["local_networks"]}    10.20.30.0/24
