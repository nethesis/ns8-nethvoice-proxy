*** Settings ***
Library   SSHLibrary
Resource  ../api.resource

*** Variables ***
# Route of a fake NethVoice instance: its dispatcher set id makes the fake
# htable entries below belong to an existing instance
${ROBOT_DOMAIN}    metrics-robot.invalid
${ROBOT_NETHVOICE}    nvrobot

*** Test Cases ***
Alerts are disabled by default
    ${response} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${response['alerts_enabled']}    ${FALSE}
    ${output}    ${rc} =    Execute Command    runagent redis-exec HKEYS module/${module_id}/metrics_alert_rules    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Contain    ${output}    proxy-

Alert rules are published
    Run task    module/${module_id}/set-alerts    {"alerts_enabled":true}
    ${response} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${response['alerts_enabled']}    ${TRUE}
    ${output}    ${rc} =    Execute Command    runagent redis-exec HKEYS module/${module_id}/metrics_alert_rules    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    proxy-services
    Should Contain    ${output}    proxy-telephony
    ${output}    ${rc} =    Execute Command    runagent redis-exec HGET module/${module_id}/metrics_alert_rules proxy-telephony    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    alert: NethVoiceTrunkUnreachable

Service state is exported
    ${output}    ${rc} =    Execute Command    runagent -m ${module_id} export-metrics    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    nethvoice_proxy_service_up{service="kamailio"} 1
    Should Contain    ${output}    nethvoice_proxy_service_restarts_total{service="kamailio"}
    Should Contain    ${output}    nethvoice_proxy_exporter_collector_up{collector="kamailio"} 1
    Should Not Contain    ${output}    module=

Trunk htables exist
    ${output}    ${rc} =    Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd htable.listTables    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    name: nvtrunkreg
    Should Contain    ${output}    name: nvtrunkopt

Trunk metrics are exported
    ${output} =    Export metrics
    Should Contain    ${output}    \# HELP nethvoice_proxy_trunk_registration_status_code
    Should Contain    ${output}    \# TYPE nethvoice_proxy_trunk_registration_status_code gauge
    Should Contain    ${output}    \# HELP nethvoice_proxy_trunk_options_status_code
    Should Contain    ${output}    \# TYPE nethvoice_proxy_trunk_options_status_code gauge

Trunk answers are exported per NethVoice instance
    [Setup]    Add the test route
    [Teardown]    Remove the test entries
    ${setid} =    Read the test route set id
    Set Test Variable    ${setid}
    Set htable entry    nvtrunkreg    ${setid}|nvrobot@example.org    403
    Set htable entry    nvtrunkopt    ${setid}|192.0.2.10:5060    408
    ${output} =    Export metrics
    Should Contain    ${output}    nethvoice_proxy_trunk_registration_status_code{nethvoice="${ROBOT_NETHVOICE}",trunk="nvrobot@example.org"} 403
    Should Contain    ${output}    nethvoice_proxy_trunk_options_status_code{nethvoice="${ROBOT_NETHVOICE}",trunk="192.0.2.10:5060"} 408
    # The entries of a removed instance stay in the htables until autoexpire
    Run task    module/${module_id}/remove-route    {"domain":"${ROBOT_DOMAIN}"}
    ${output} =    Export metrics
    Should Not Contain    ${output}    nvrobot

Publishing changed rules sends the event
    ${output}    ${rc} =    Execute Command    runagent redis-exec HDEL module/${module_id}/metrics_alert_rules proxy-services    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${events} =    Publish rules and watch the event
    Should Contain    ${events}    message

Publishing unchanged rules sends no event
    ${events} =    Publish rules and watch the event
    Should Not Contain    ${events}    message

Disabling the alerts removes the rules
    Run task    module/${module_id}/set-alerts    {"alerts_enabled":false}
    ${output}    ${rc} =    Execute Command    runagent redis-exec HKEYS module/${module_id}/metrics_alert_rules    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Contain    ${output}    proxy-

*** Keywords ***
Export metrics
    ${output}    ${rc} =    Execute Command    runagent -m ${module_id} export-metrics    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    nethvoice_proxy_exporter_collector_up{collector="kamailio"} 1
    RETURN    ${output}

Add the test route
    Set Test Variable    ${setid}    ${EMPTY}
    Run task    module/${module_id}/add-route
    ...    {"domain":"${ROBOT_DOMAIN}","address":[{"uri":"sip:127.0.0.1:34995","description":"${ROBOT_NETHVOICE}"}]}

Read the test route set id
    ${output}    ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgres sh -c 'exec psql -tA -U "$POSTGRES_USER" "$POSTGRES_DB" -c "$1"' sh "SELECT setid FROM dispatcher WHERE description = '${ROBOT_NETHVOICE}'"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Match Regexp    ${output}    ^[0-9]+$
    RETURN    ${output}

Set htable entry
    [Arguments]    ${table}    ${key}    ${value}
    # kamcmd exits 0 on errors too: check its answer
    ${output} =    Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd htable.seti ${table} '${key}' ${value}
    Should Contain    ${output}    Ok.

Remove the test entries
    IF    $setid
        Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd htable.delete nvtrunkreg '${setid}|nvrobot@example.org'
        Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd htable.delete nvtrunkopt '${setid}|192.0.2.10:5060'
    END
    Run task    module/${module_id}/remove-route    {"domain":"${ROBOT_DOMAIN}"}

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
