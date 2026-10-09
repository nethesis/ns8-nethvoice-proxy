*** Settings ***
Resource       ./metrics_alerts.resource
Suite Setup    Require Proxy Alert Test Environment

*** Variables ***
${RUN_METRICS_ALERT_RULES_E2E}    ${FALSE}

*** Test Cases ***
Check if metrics loads and scopes all five proxy alerts
    Proxy Rules Should Be Loaded
    All Proxy Alerts Should Be Inactive

Check if stopped Kamailio alerts and recovers
    [Teardown]    Start Proxy Service And Wait For Recovery    kamailio.service    NethVoiceProxyKamailioDown
    Change Proxy Service State    stop    kamailio.service
    Wait Until Keyword Succeeds    30x    5s    Proxy Alert State Should Be    NethVoiceProxyKamailioDown    pending
    Wait Until Keyword Succeeds    45x    10s    Proxy Alert State Should Be    NethVoiceProxyKamailioDown    firing

Check if an exporter outage suppresses service alerts and recovers
    [Teardown]    Start Proxy Service And Wait For Recovery    systemd-exporter.service    NethVoiceProxySystemdExporterDown
    Change Proxy Service State    stop    systemd-exporter.service
    Wait Until Keyword Succeeds    30x    5s    Proxy Alert State Should Be    NethVoiceProxySystemdExporterDown    pending
    Wait Until Keyword Succeeds    45x    10s    Proxy Alert State Should Be    NethVoiceProxySystemdExporterDown    firing
    ${rules} =    Read Loaded Proxy Rules
    FOR    ${rule}    IN    @{rules}
        IF    $rule["name"] != "NethVoiceProxySystemdExporterDown"
            Should Be Equal    ${rule}[state]    inactive
        END
    END

*** Keywords ***
Require Proxy Alert Test Environment
    ${enabled} =    Convert To Boolean    ${RUN_METRICS_ALERT_RULES_E2E}
    Skip If    not $enabled    Requires an explicitly selected disposable node with compatible metrics
    ${metrics_id} =    Run Proxy Metrics Command    redis-cli --raw GET cluster/default_instance/metrics
    Should Not Be Empty    ${metrics_id}
    ${path} =    Run Proxy Metrics Command    runagent -m ${metrics_id} printenv PROMETHEUS_PATH
    ${prefix} =    Evaluate    "/" + $path.strip("/") if $path.strip("/") else ""
    Set Suite Variable    ${PROMETHEUS_BASE_URL}    http://127.0.0.1:9091${prefix}
    FOR    ${unit}    IN    kamailio.service    rtpengine.service    postgres.service    redis.service    systemd-exporter.service
        Run Proxy Metrics Command    runagent -m ${module_id} systemctl --user is-active --quiet ${unit}
    END
    Wait Until Keyword Succeeds    30x    10s    Proxy Rules Should Be Loaded
    Wait Until Keyword Succeeds    30x    5s    All Proxy Alerts Should Be Inactive

Proxy Rules Should Be Loaded
    ${rules} =    Read Loaded Proxy Rules
    Length Should Be    ${rules}    5
    ${actual} =    Evaluate    {rule["name"]: rule["labels"]["service"] for rule in $rules}
    Should Be Equal    ${actual}    ${PROXY_ALERT_SERVICES}
    FOR    ${rule}    IN    @{rules}
        Should Be Equal    ${rule}[health]    ok
        Should Be Equal    ${rule}[labels][severity]    critical
        Should Be Equal As Numbers    ${rule}[duration]    300
        ${count} =    Evaluate    $rule["query"].count('module_id="' + $module_id + '"')
        ${expected} =    Evaluate    1 if $rule["name"] == "NethVoiceProxySystemdExporterDown" else 2
        Should Be Equal As Integers    ${count}    ${expected}
    END

Read Loaded Proxy Rules
    ${output} =    Run Proxy Metrics Command
    ...    curl --fail --silent --show-error --max-time 10 ${PROMETHEUS_BASE_URL}/api/v1/rules
    ${groups} =    Evaluate    json.loads($output)["data"]["groups"]    modules=json
    ${rules} =    Evaluate    [rule for group in $groups for rule in group["rules"] if rule.get("labels", {}).get("module_id") == $module_id and rule["name"].startswith("NethVoiceProxy")]
    Should Not Be Empty    ${rules}
    RETURN    ${rules}

Proxy Alert State Should Be
    [Arguments]    ${name}    ${state}
    ${rules} =    Read Loaded Proxy Rules
    ${matches} =    Evaluate    [rule for rule in $rules if rule["name"] == $name]
    Length Should Be    ${matches}    1
    Should Be Equal    ${matches}[0][health]    ok
    Should Be Equal    ${matches}[0][state]    ${state}

All Proxy Alerts Should Be Inactive
    ${rules} =    Read Loaded Proxy Rules
    Length Should Be    ${rules}    5
    FOR    ${rule}    IN    @{rules}
        Should Be Equal    ${rule}[health]    ok
        Should Be Equal    ${rule}[state]    inactive
    END

Change Proxy Service State
    [Arguments]    ${action}    ${unit}
    Run Proxy Metrics Command    runagent -m ${module_id} systemctl --user ${action} ${unit}

Start Proxy Service And Wait For Recovery
    [Arguments]    ${unit}    ${alert}
    Change Proxy Service State    start    ${unit}
    Wait Until Keyword Succeeds    30x    5s    Proxy Alert State Should Be    ${alert}    inactive
    Wait Until Keyword Succeeds    30x    5s    All Proxy Alerts Should Be Inactive
