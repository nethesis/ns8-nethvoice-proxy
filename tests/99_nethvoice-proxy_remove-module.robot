*** Settings ***
Library    SSHLibrary

*** Test Cases ***
Check if nethvoice-proxy is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if the systemd metrics target is removed correctly
    ${target} =    Execute Command    redis-cli --raw HGET module/${module_id}/metrics_targets systemd
    Should Be Empty    ${target}

Check if owned alert rules are removed correctly
    FOR    ${field}    IN    systemd-exporter    core-services
        ${rule}    ${rc} =    Execute Command    redis-cli --raw HGET module/${module_id}/metrics_alert_rules ${field}
        ...    return_rc=True
        Should Be Equal As Integers    ${rc}    0
        Should Be Empty    ${rule}
    END
