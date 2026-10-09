*** Settings ***
Resource    ./metrics_alerts.resource

*** Variables ***
${UPGRADED_MODULE_ID}    ${EMPTY}
${RESTORED_MODULE_ID}    ${EMPTY}
${CLONED_MODULE_ID}      ${EMPTY}

*** Test Cases ***
Check metrics publication after upgrade
    Skip If    not $UPGRADED_MODULE_ID    Set UPGRADED_MODULE_ID after upgrading a disposable instance
    Proxy Metrics Should Be Published    ${UPGRADED_MODULE_ID}

Check destination metrics publication after restore
    Skip If    not $RESTORED_MODULE_ID    Set RESTORED_MODULE_ID after restoring a disposable instance
    Proxy Metrics Should Be Published    ${RESTORED_MODULE_ID}

Check destination metrics publication after clone
    Skip If    not $CLONED_MODULE_ID    Set CLONED_MODULE_ID after cloning a disposable instance
    Proxy Metrics Should Be Published    ${CLONED_MODULE_ID}
