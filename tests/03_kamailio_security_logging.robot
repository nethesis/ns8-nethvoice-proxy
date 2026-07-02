*** Settings ***
Library   SSHLibrary

*** Test Cases ***
Kamailio failure route logs failed SIP authentication
    [Documentation]    failure_route[MANAGE_FAILURE] must contain the
    ...                structured SECURITY-AUTHFAIL xlog line used by the
    ...                CrowdSec parser to detect bruteforce logins.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio awk '/^failure_route\\[MANAGE_FAILURE\\]/,/^} # end of failure_route\\[MANAGE_FAILURE\\]/' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    SECURITY-AUTHFAIL
    Should Contain    ${output}    event=auth_failure

Kamailio failure route uses the saved AVP source IP, not reply source IP
    [Documentation]    The auth-failure log must use $avp(src_ip) (the real
    ...                client, saved as a transaction-scoped AVP since
    ...                $dlg_var only persists for dialog-creating requests
    ...                like INVITE, not REGISTER), never $si, which in this
    ...                route context is the Asterisk backend IP.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'src_ip=\\$avp(src_ip)' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio failure route does not log the initial 401/407 digest challenge
    [Documentation]    Requests without Authorization/Proxy-Authorization
    ...                must not be flagged as auth failures, or every
    ...                legitimate REGISTER would look like an attack.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'hdr(Authorization)' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be True    ${output} >= 1

Kamailio does not run with ANSI color escapes enabled
    [Documentation]    The -e flag corrupts journald log lines with ANSI
    ...                escape codes, breaking CrowdSec's grok parser.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio sh -c "pgrep -a kamailio || ps -eo args | grep '[k]amailio'"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Match Regexp    ${output}    \\s-e(\\s|$)
    Should Contain    ${output}    -E
