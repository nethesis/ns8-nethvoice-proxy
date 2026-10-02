*** Settings ***
Resource    ../api.resource
Resource    ../metrics_alerts.resource

*** Test Cases ***
Check if reconfiguration republishes missing alert rules
    [Teardown]    Update Proxy Alert Rules
    ${config} =    Run Task    module/${module_id}/get-configuration    {}
    ${input} =    Evaluate    json.dumps($config)    modules=json
    Run Proxy Metrics Command    runagent -m ${module_id} prometheus-alert-rules remove
    Run Task    module/${module_id}/configure-module    ${input}
    Proxy Metrics Should Be Published
