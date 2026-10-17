*** Settings ***
Library    SSHLibrary
Library    Collections

*** Variables ***
&{PROXY_ALERT_SERVICES}
...    NethVoiceProxyKamailioDown=kamailio.service
...    NethVoiceProxyRTPengineDown=rtpengine.service
...    NethVoiceProxyPostgreSQLDown=postgres.service
...    NethVoiceProxyRedisDown=redis.service
...    NethVoiceProxySystemdExporterDown=systemd-exporter.service

*** Keywords ***
Run Proxy Metrics Command
    [Arguments]    ${command}
    ${stdout}    ${stderr}    ${rc} =    Execute Command    ${command}
    ...    return_stderr=True    return_rc=True
    Should Be Equal As Integers    ${rc}    0    ${stderr}
    RETURN    ${stdout}

Proxy Metrics Should Be Published
    [Arguments]    ${instance}=${module_id}
    ${rules} =    Create List
    FOR    ${field}    IN    systemd-exporter    core-services
        ${document} =    Run Proxy Metrics Command    redis-cli --raw HGET module/${instance}/metrics_alert_rules ${field}
        Should Not Be Empty    ${document}
        ${groups} =    Evaluate    yaml.safe_load($document)["groups"]    modules=yaml
        Length Should Be    ${groups}    1
        Should Be Equal    ${groups}[0][name]    nethvoice-proxy.${field}
        ${count} =    Evaluate    1 if $field == "systemd-exporter" else 4
        Length Should Be    ${groups}[0][rules]    ${count}
        FOR    ${rule}    IN    @{groups}[0][rules]
            Append To List    ${rules}    ${rule}
        END
    END
    ${actual} =    Evaluate    {rule["alert"]: rule["labels"]["service"] for rule in $rules}
    Should Be Equal    ${actual}    ${PROXY_ALERT_SERVICES}
    FOR    ${rule}    IN    @{rules}
        Should Be Equal    ${rule}[for]    5m
        Should Be Equal    ${rule}[labels][severity]    critical
        Dictionary Should Not Contain Key    ${rule}[labels]    module_id
        Should Not Contain    ${rule}[expr]    module_id="
        FOR    ${language}    IN    en    it
            Should Not Be Empty    ${rule}[annotations][summary_${language}]
            Should Contain    ${rule}[annotations][description_${language}]    {{ $labels.module_id }}
            Should Contain    ${rule}[annotations][description_${language}]    {{ $labels.node }}
        END
    END

    ${runtime_json} =    Run Proxy Metrics Command
    ...    runagent -m ${instance} python3 -c 'import agent, json, os; env = agent.read_envfile("environment"); print(json.dumps({"module": os.environ["MODULE_ID"], "node": os.environ["NODE_ID"], "port": env["NETHVOICE_PROXY_SYSTEMD_EXPORTER_PORT"], "path": env["SYSTEMD_EXPORTER_PROMETHEUS_PATH"]}))'
    ${runtime} =    Evaluate    json.loads($runtime_json)    modules=json
    Should Be Equal    ${runtime}[module]    ${instance}
    ${address} =    Run Proxy Metrics Command    redis-cli --raw HGET node/${runtime}[node]/vpn ip_address
    Should Not Be Empty    ${address}
    ${target_yaml} =    Run Proxy Metrics Command    redis-cli --raw HGET module/${instance}/metrics_targets systemd
    ${targets} =    Evaluate    yaml.safe_load($target_yaml)    modules=yaml
    Length Should Be    ${targets}    1
    Length Should Be    ${targets}[0][targets]    1
    Should Be Equal    ${targets}[0][targets][0]    ${address}:${runtime}[port]
    Should Be Equal    ${targets}[0][labels][module_id]    ${instance}
    Should Be Equal As Strings    ${targets}[0][labels][node]    ${runtime}[node]
    Should Be Equal    ${targets}[0][labels][__metrics_path__]    ${runtime}[path]

Update Proxy Alert Rules
    [Arguments]    ${instance}=${module_id}
    Run Proxy Metrics Command    runagent -m ${instance} prometheus-alert-rules update
