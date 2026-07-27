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

Kamailio failure route uses the transaction reply code, not the request status
    [Documentation]    status= must come from $T_reply_code (tmx), since $rs
    ...                in failure_route reads the replayed original request
    ...                (always empty), not the backend's reply code.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'status=\\$T_reply_code' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio failure route skips loopback source IPs
    [Documentation]    topos re-injects the message with a loopback src_ip
    ...                (127.0.0.1 / ::1); logging it would feed a bogus
    ...                localhost ban candidate to CrowdSec, so both must be
    ...                excluded by the guard.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'src_ip) != "127.0.0.1"' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1
    ${output6}  ${rc6} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'src_ip) != "::1"' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc6}    0
    Should Be Equal As Integers    ${output6}    1

Kamailio failure route skips outbound trunk direction
    [Documentation]    The guard only logs auth failures for inbound traffic
    ...                ($avp(direction) or $dlg_var(direction) == 'in'), so
    ...                outbound trunk requests are never flagged as attacks.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c '\\$avp(direction) == "in" || \\$dlg_var(direction) == "in"' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio failure route sanitizes attacker-controlled log fields
    [Documentation]    The To-URI username and Call-ID are attacker-controlled
    ...                and must be charset-validated before being written to
    ...                the log line, so a crafted value can't inject extra
    ...                key=value pairs into the CrowdSec grok parser input.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'var(auth_user) = "invalid"' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1
    ${outputc}  ${rcc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'var(callid) = "invalid"' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rcc}    0
    Should Be Equal As Integers    ${outputc}    1

Kamailio does not run with ANSI color escapes enabled
    [Documentation]    The -e flag corrupts journald log lines with ANSI
    ...                escape codes, breaking CrowdSec's grok parser.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio sh -c "pgrep -a kamailio || ps -eo args | grep '[k]amailio'"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Match Regexp    ${output}    \\s-e(\\s|$)
    Should Contain    ${output}    -E
