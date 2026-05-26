*** Settings ***
Resource    ui.resource
Suite Teardown    Run Keyword And Ignore Error    Close Browser

*** Test Cases ***

Take screenshots
    [Tags]    ui
    Open Browser To Cluster Admin    ${NODE_ADDR}
    Open App Status Page    ${NODE_ADDR}    ${module_id}
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/1._Status.png
    Open App Settings Page    ${NODE_ADDR}    ${module_id}
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/2._Settings.png
