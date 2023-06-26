*** Settings ***
Library    SSHLibrary

*** Test Cases ***
Start Postgress service
    ${output}  ${rc} =    Execute Command  ssh -o StrictHostKeyChecking=no ${module_id}@localhost systemctl --user start postgres
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
