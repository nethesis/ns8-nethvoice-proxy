*** Settings ***
Library    SSHLibrary
Library    Collections
Library    String
Resource   ../api.resource
Suite Setup    Wait For Kamailio

*** Test Cases ***
List allocated slot port ranges
    ${response} =  Run task    module/${module_id}/list-slot-port-ranges    {}
    Should Be Equal As Numbers    ${response["slot_count"]}    5
    Should Be Equal As Numbers    ${response["udp_tcp_port_start"]}    5071
    Should Be Equal As Numbers    ${response["udp_tcp_port_end"]}    5075
    Should Be Equal As Numbers    ${response["tls_port_start"]}    6071
    Should Be Equal As Numbers    ${response["tls_port_end"]}    6075

Default firewall service exposes slot ranges
    ${ports} =    Execute Command    firewall-cmd --permanent --service=${module_id} --get-ports
    Should Contain    ${ports}    5071-5075/tcp
    Should Contain    ${ports}    5071-5075/udp
    Should Contain    ${ports}    6071-6075/tcp

List of slot domains should be empty
    ${response} =  Run task    module/${module_id}/list-slot-domains    {}
    Should Be Empty    ${response}

Add slot-managed domains
    Run task    module/${module_id}/add-slot-domain
    ...    {"domain":"sip.vianova1.example"}
    Run task    module/${module_id}/add-slot-domain
    ...    {"domain":"sip.vianova2.example"}
    Run task    module/${module_id}/add-slot-domain
    ...    {"domain":"sip.vianova1.example"}

List configured slot-managed domains
    ${response} =  Run task    module/${module_id}/list-slot-domains    {}
    ${list_len} =  Get Length    ${response}
    Should Be Equal As Numbers    2    ${list_len}
    Should Be Equal    ${response[0]["domain"]}    sip.vianova1.example
    Should Be Empty    ${response[0]["assignments"]}
    Should Be Equal    ${response[1]["domain"]}    sip.vianova2.example
    Should Be Empty    ${response[1]["assignments"]}

List active slot assignments with ttl
    Execute Command    runagent -m ${module_id} podman exec -i postgres psql -v ON_ERROR_STOP=1 -U postgres kamailio -c "INSERT INTO slot_assignments (key_name, key_type, value_type, key_value, expires) VALUES ('alice::sip.vianova1.example', 0, 0, 'slot1', 0) ON CONFLICT (key_name) DO UPDATE SET key_value = EXCLUDED.key_value, expires = EXCLUDED.expires"
    Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd htable.setxs slotassign alice::sip.vianova1.example slot1 3600
    Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd htable.seti slotpool slot1 1
    ${response} =  Run task    module/${module_id}/list-slot-domains    {}
    ${assignment} =    Set Variable    ${response[0]["assignments"][0]}
    Should Be Equal    ${assignment["username"]}    alice
    Should Be Equal    ${assignment["slot"]}    slot1
    Should Be Equal As Numbers    ${assignment["port"]}    5071
    Should Be Equal As Numbers    ${assignment["tls_port"]}    6071
    Should Be True    ${assignment["ttl"]} > 0

Remove slot-managed domain frees assignments
    Run task    module/${module_id}/remove-slot-domain
    ...    {"domain":"sip.vianova1.example"}
    ${remaining} =    Execute Command    runagent -m ${module_id} podman exec -i postgres psql -tA -U postgres kamailio -c "SELECT COUNT(*) FROM slot_assignments WHERE key_name='alice::sip.vianova1.example';"
    ${remaining} =    Strip String    ${remaining}
    Should Be Equal    ${remaining}    0
    ${slotpool} =    Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd htable.get slotpool slot1
    Should Contain    ${slotpool}    0
    ${response} =  Run task    module/${module_id}/list-slot-domains    {}
    ${list_len} =  Get Length    ${response}
    Should Be Equal As Numbers    1    ${list_len}
    Should Be Equal    ${response[0]["domain"]}    sip.vianova2.example

Remove remaining slot-managed domain
    Run task    module/${module_id}/remove-slot-domain
    ...    {"domain":"sip.vianova2.example"}
    ${response} =  Run task    module/${module_id}/list-slot-domains    {}
    Should Be Empty    ${response}

*** Keywords ***
Wait For Kamailio
    Wait Until Keyword Succeeds    5 min    10 sec    Kamailio should be responding

Kamailio should be responding
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman exec kamailio kamcmd core.uptime
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    uptime
