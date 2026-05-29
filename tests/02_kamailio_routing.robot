*** Settings ***
Library   SSHLibrary

*** Test Cases ***
Kamailio config defines ADD_X_FORWARDED_FOR route
    [Documentation]    The route that injects the X-Forwarded-For header on
    ...                inbound INVITEs must be defined in the runtime config.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c '^route\\[ADD_X_FORWARDED_FOR\\]' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio config inserts X-Forwarded-For with source IP
    [Documentation]    The route body must remove any existing header and
    ...                insert one carrying the source IP variable ($si).
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -E 'insert_hf\\(.*X-Forwarded-For:[[:space:]]*\\$si' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    X-Forwarded-For

Kamailio main flow invokes ADD_X_FORWARDED_FOR on initial INVITE
    [Documentation]    The main inbound branch (direction=in) must call the
    ...                route guarded by is_method INVITE and !has_totag.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'route(ADD_X_FORWARDED_FOR)' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    # Two call sites: main flow + HANDLE_ALIAS shortcut
    Should Be True    ${output} >= 2

Kamailio HANDLE_ALIAS shortcut also tags X-Forwarded-For
    [Documentation]    When handle_ruri_alias() shortcuts to RELAY, the
    ...                header tagging must still run, otherwise INVITEs with
    ...                an ;alias= param reach Asterisk without the header.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio awk '/^route\\[HANDLE_ALIAS\\]/,/^} # end of route\\[HANDLE_ALIAS\\]/' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    route(ADD_X_FORWARDED_FOR)

Kamailio kamcmd reports the running config without parse errors
    [Documentation]    A loaded broken config would have prevented the
    ...                container from staying up; this asserts kamcmd still
    ...                answers, confirming the runtime accepted the cfg.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio kamcmd core.uptime
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    uptime
