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
