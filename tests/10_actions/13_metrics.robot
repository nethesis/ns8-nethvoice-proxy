*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Test Cases ***
Alert rules are published
    ${output}    ${rc} =    Execute Command    runagent redis-exec HKEYS module/${module_id}/metrics_alert_rules    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    proxy-services
    Should Contain    ${output}    proxy-telephony

Service state is exported
    ${output}    ${rc} =    Execute Command    runagent -m ${module_id} export-metrics    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    nethvoice_proxy_service_up{service="kamailio"} 1
    Should Contain    ${output}    nethvoice_proxy_service_restarts_total{service="kamailio"}
    Should Contain    ${output}    nethvoice_proxy_exporter_collector_up{collector="kamailio"} 1
    Should Not Contain    ${output}    module=

Publishing changed rules sends the event
    ${output}    ${rc} =    Execute Command    runagent redis-exec HDEL module/${module_id}/metrics_alert_rules proxy-services    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${events} =    Publish rules and watch the event
    Should Contain    ${events}    message

Publishing unchanged rules sends no event
    ${events} =    Publish rules and watch the event
    Should Not Contain    ${events}    message

*** Keywords ***
Publish rules and watch the event
    # The subscriber prints "subscribe" when ready and "message" for every
    # event; publish-metrics-config writes only to stderr
    ${events}    ${rc} =    Execute Command
    ...    timeout 8 redis-cli --raw SUBSCRIBE module/${module_id}/event/metrics-alert-rules-changed & sleep 2; runagent -m ${module_id} publish-metrics-config; rc=$?; wait; exit $rc
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${events}    subscribe
    ${output}    ${rc} =    Execute Command    runagent redis-exec HKEYS module/${module_id}/metrics_alert_rules    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    proxy-services
    RETURN    ${events}
