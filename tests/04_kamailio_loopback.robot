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

Kamailio loopback BYE toward the provider is a new request of the proxy
    [Documentation]    The BYE that closes the trunk-out leg is built with
    ...                t_uac_send() from the From, To, To-tag and CSeq of
    ...                the setup, not forwarded from the BYE of the other
    ...                side: that one has the tags and the CSeq of the other
    ...                dialog, and its Request-URI makes topos rewrite the
    ...                Call-ID. The provider answered 481 to both.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 't_uac_send("BYE"' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -cE 'trunk_out_(from|to|tt|cseq)_[$]ft[)] = ' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    4

Kamailio loopback BYE toward the provider skips topos
    [Documentation]    topos binds the BYE to the reflected dialog through
    ...                its Request-URI token: the BYE marked in loopback_bye
    ...                must leave as built.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'is_method("BYE") && $sht(loopback_bye=>$ci) != $null' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio loopback code never tests a $var against $null
    [Documentation]    Assigning $null to a $var stores 0, so a $var is never
    ...                equal to $null: the loopback code resets its $var to
    ...                "" and tests them against "" or a pattern.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -cE '[$]var[(](lb|out|absorb|uas|target)_[a-z_]+[)] [!=]= [$]null' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${output}    0

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

Kamailio answers the reflected loopback SDP with SDES
    [Documentation]    The reflected SDP is the SRTP offer rtpengine made for
    ...                the trunk-out leg, with SDES and DTLS. Answered with
    ...                DTLS, the reflected leg dropped the caller audio as
    ...                SRTP errors: the DTLS attributes are removed and the
    ...                reflected leg keeps DTLS=off.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'sdp_remove_line_by_prefix("a=fingerprint")' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c ' DTLS=off' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio gives the dialog context back to the loopback BYE
    [Documentation]    dlg_get() in route[LOOPBACK_CLOSE_TRUNK] moves the
    ...                dialog context; the BYE is forwarded statelessly and
    ...                the dialog module releases a reference of the context
    ...                dialog: it must be the dialog of the BYE again.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'dlg_get("$var(lb_own_ci)", "$var(lb_own_ft)", "$var(lb_own_tt)")' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio retransmits the loopback BYE for FR_TIMEOUT_BYE
    [Documentation]    t_uac_send() ignores t_set_fr(): the BYE uses the tm
    ...                settings instance 1, selected around t_uac_send().
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c -e 'tm\\[1\\].fr_timer = FR_TIMEOUT_BYE' -e 'cfg_select("tm", 1)' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    2

Kamailio uses the whole route set of the trunk
    [Documentation]    The rebuilt ACK and the loopback BYE carry every
    ...                Record-Route entry of the 2xx that is not the proxy,
    ...                in reverse order, not only the first header.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'route(UAC_ROUTE_SET)' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    2

Kamailio closes the reflected dialog with the reflected BYE
    [Documentation]    The BYE the provider reflects back goes through
    ...                loose_route() before the 200 OK, so the reflected
    ...                dialog is closed and does not expire with a warning.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -A6 'event=provider_bye_absorbed' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    loose_route();

Kamailio gives the reflected leg its Call-ID back before the dialog module
    [Documentation]    topos unmasks the Call-ID of every request of the
    ...                provider to the one of the caller side: a re-INVITE or
    ...                an UPDATE on the reflected leg took the dialog and the
    ...                rtpengine session of the caller side and kept DTLS.
    ...                route[LOOPBACK_REFLECTED] runs before dlg_manage().
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -A3 'route(LOOPBACK_REFLECTED);' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    dlg_manage();
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'isflagset(FLT_LB_REFLECTED) && is_method("INVITE|UPDATE|PRACK")' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio refuses SDP in the loopback rewrite
    [Documentation]    Relayed as it is, the SDP of one side would bring the
    ...                SRTP offer and the external rtpengine port to the
    ...                other Asterisk: the rewrite answers 488 instead.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -A1 'event=sdp_refused' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    sl_send_reply("488", "Not Acceptable Here");

Kamailio renumbers the CSeq of the loopback rewrite
    [Documentation]    Asterisk answers 500 Invalid CSeq to a request below
    ...                the highest CSeq it got on that dialog, e.g. after an
    ...                UPDATE of the provider. The rewrite keeps a CSeq above
    ...                it and the replies get the CSeq of the sender back.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c -e 'event=cseq_renumbered' -e '^onreply_route {' -e 'loopback_rq=>size=8;autoexpire=60;' -e 'loopback_rpl=>size=8;autoexpire=60;' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    4

Kamailio loose-routes in-dialog requests without strict router handling
    [Documentation]    On a loopback call the remote target is a Contact of
    ...                the proxy: loose_route() took the previous hop for a
    ...                strict router and sent a re-INVITE of Asterisk to the
    ...                own Record-Route, 408 and the call dropped.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -c 'if (loose_route_mode("1")) {' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${output}    1

Kamailio gives the reflected leg Call-ID also to a provider CANCEL
    [Documentation]    A CANCEL of a re-INVITE on the reflected leg must
    ...                carry the Call-ID of that leg, or t_check_trans()
    ...                does not find the transaction and the CANCEL is lost.
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec kamailio grep -B1 'route(LOOPBACK_REFLECTED);' /etc/kamailio/kamailio.cfg
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Contain    ${output}    CANCEL
