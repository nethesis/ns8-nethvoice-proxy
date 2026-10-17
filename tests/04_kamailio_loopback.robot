*** Settings ***
Library   SSHLibrary

*** Test Cases ***
Kamailio loads topoh in library mode only
    [Documentation]    topos mask_callid binds to the topoh API. Without
    ...                use_mode 1 topoh also hides the topology of every
    ...                message, on top of topos.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'modparam("topoh", "use_mode", 1)' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio topoh mask key is generated per instance
    [Documentation]    The Call-ID mask key comes from TOPOH_MASK_KEY, a
    ...                random value written in passwords.env when the module
    ...                is created or updated, never from a key in the repo.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio printenv TOPOH_MASK_KEY
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Match Regexp    ${output}    ^[0-9a-f]{32}$
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'modparam("topoh", "mask_key", TOPOH_MASK_KEY)' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio loopback BYE toward the provider uses the socket of the setup
    [Documentation]    With BEHIND_NAT the proxy listens on PRIVATE_IP and a
    ...                trunk may not be on port 5060: the socket must come
    ...                from the 2xx of the setup, not from PUBLIC_IP:5060.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'env(PUBLIC_IP)' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${output}    0
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'trunk_out_sock_$ft) = $pr + ":" + $Ri + ":" + $Rp' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio keeps outgoing calls only briefly for loopback detection
    [Documentation]    Every outgoing INVITE is stored in loopback_pending,
    ...                which expires in seconds; only a detected loopback
    ...                reaches the long lived loopback table.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'loopback_pending=>size=10;autoexpire=30;' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio loopback rewrite keeps the dialog tags
    [Documentation]    The cross-dialog rewrite changes only Call-ID and
    ...                Request-URI. A To rewrite with uac_replace_to is
    ...                declined by uac in sequential requests (restore_dlg)
    ...                and, from the callee side, would set the To-tag to the
    ...                tag of the sender.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'uac_replace_to' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${output}    0

Kamailio rebuilds the ACK only toward an upstream Record-Route
    [Documentation]    The end-to-end ACK rebuild is for trunks that
    ...                record-route. When the top Record-Route of the 2xx is
    ...                the proxy itself (an extension behind NAT) the ACK
    ...                must follow the normal relay, or it is sent back to
    ...                the proxy and the extension never gets it.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c '!is_myself("$var(rr_uri)")' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1
