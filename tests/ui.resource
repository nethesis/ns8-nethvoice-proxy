*** Settings ***
Library    Browser
Library    OperatingSystem

*** Keywords ***
Open Browser To Cluster Admin
    [Arguments]    ${node_addr}
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True
    New Page    https://${node_addr}/cluster-admin/
    Login To Cluster Admin

Login To Cluster Admin
    ${admin_user} =    Get Environment Variable    ADMIN_USER    admin
    ${admin_password} =    Get Environment Variable    ADMIN_PASSWORD    Nethesis,1234
    Wait For Elements State    css=input[name="username"]    visible    timeout=20s
    Fill Text    css=input[name="username"]    ${admin_user}
    Click    css=.login-button
    Wait For Elements State    css=input[type="password"]    visible    timeout=20s
    Fill Text    css=input[type="password"]    ${admin_password}
    Click    css=.login-button
    Wait For Elements State    css=#main-content    visible    timeout=20s

Open App Status Page
    [Arguments]    ${node_addr}    ${module_id}
    Go To    https://${node_addr}/cluster-admin/#/apps/${module_id}
    Wait For Elements State    iframe >>> css=.page-title h2    visible    timeout=30s
    Get Text    iframe >>> css=.page-title h2    ==    Status
    Wait For Elements State
    ...    iframe >>> css=.page-subtitle h4 >> nth=0
    ...    visible
    ...    timeout=30s

Open App Settings Page
    [Arguments]    ${node_addr}    ${module_id}
    Go To    https://${node_addr}/cluster-admin/#/apps/${module_id}?page=settings
    Wait For Elements State    iframe >>> css=.page-title h2    visible    timeout=30s
    Get Text    iframe >>> css=.page-title h2    ==    Settings
    Wait For Elements State    iframe >>> css=form    visible    timeout=30s
    Wait For Elements State
    ...    iframe >>> css=form button.bx--btn--primary
    ...    enabled
    ...    timeout=30s

Save Settings Form
    Click    iframe >>> css=form button.bx--btn--primary
    Wait For Elements State
    ...    iframe >>> css=form button.bx--btn--primary
    ...    disabled
    ...    timeout=10s
    Wait For Elements State
    ...    iframe >>> css=form button.bx--btn--primary
    ...    enabled
    ...    timeout=90s

Assert No Settings Errors
    ${errors} =    Get Element Count    iframe >>> css=.bx--inline-notification--error
    Should Be Equal As Integers    ${errors}    0
