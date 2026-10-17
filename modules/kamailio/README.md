# Kamailio container

## Environment variables

- `KAMAILIO_LOG_LEVEL` Log level passed to kamailio as `--debug`. Overrides the `debug=` value of the configuration file. Range -3..3, default 0 (warning). Example: "0"
- `KML_INTERNAL_NETWORK` Comma sepaated list of internal ip addresses. Example: "10.18.0.7,192.168.1.123" or "192.168.1.123"
- `KML_SERVER_HEADER` DESC. Example: "NethServer 8 nethvoice-proxy1"
- `KML_SIP_URL` DESC. Example: "127.0.0.1"
- `KML_UA_HEADER` DESC. Example: "NethServer 8 nethvoice-proxy1"
- `POSTGRES_DB` Kamailio Postgres DB backend name. Example: "kamailio"
- `POSTGRES_HOST` Kamailio Postgres DB backend host. Example: "127.0.0.1"
- `POSTGRES_PASSWORD` Kamailio Postgres DB backend password. Example: "MySuperSecurePassword"
- `POSTGRES_PORT` Kamailio Postgres DB backend port. Example: "20011"
- `POSTGRES_USER` Kamailio Postgres DB backend username. Example: "postgres"
- `PUBLIC_IP` Public IP of Kamailio. Example: "80.11.11.11"
- `REDIS_HOST` Redis DB backend host. Example: "127.0.0.1"
- `REDIS_PORT` Redis DB backend port. Example: "20012"
- `RTP_PORT_MIN` Kamailio RTP port range start. Example: "10000"
- `RTP_PORT_MAX` Kamailio RTP port range end. Example: "20000"
- `SIP_PORT` Kamailio SIP port. Example: "5060"
- `TOPOH_MASK_KEY` Key used to mask the Call-ID toward the trunks. Generated per instance in `passwords.env` by the NS8 module; when missing, `bootstrap.sh` uses a random key. Example: "3f2a9c0e7b1d4e6f8a5c2b9d0e1f3a4b"

## Logging

Log levels: `3` debug, `2` info, `1` notice, `0` warning (default), `-1` error,
down to `-3`. The lower the value, the fewer messages are printed.

The default is `0`: warnings and errors are printed, and the security lines of
the script, such as the failed authentications and the blocked IP addresses,
are logged at warning level so they are always visible.

### Persistent log level

Set `kamailio_log_level` with the `configure-module` action of the NS8 module.
It writes `KAMAILIO_LOG_LEVEL` in the instance environment, and the container
starts kamailio with `--debug=<value>`, which takes precedence over the
`debug=` value in `kamailio.cfg`. A service restart is required. When the
variable is not set, the value from the configuration file is used, which is
`debug=0` as well. Leaving `kamailio_log_level` out of the `configure-module`
input keeps the level currently stored in the environment.

### Temporary log level, no restart

```
kamcmd corex.debug 3      # raise, to troubleshoot a live issue
kamcmd corex.debug 0      # back to the default
```

The change is lost on restart. At level 3 a single REGISTER produces
around 400 lines, so raise it only while investigating.

### Noisy core messages

`corelog` covers the TCP send and read errors of the core, `sip_parser_log`
the errors logged for packets that are not SIP (for example proprietary
keepalives). Both are set to `3` in `kamailio.cfg`, so those messages are
logged as debug instead of error. The `cfg_rpc` module allows changing them at
runtime:

```
kamcmd cfg.get core corelog
kamcmd cfg.set_now_int core corelog -1        # restore the core TCP errors
kamcmd cfg.set_now_int core sip_parser_log -1 # restore the non-SIP parse errors
```

### Development tracing

The `[DEV]` and `[TT157]` lines are logged at debug level and guarded by a
runtime flag, so both are needed to see them:

```
kamcmd corex.debug 3
kamcmd pv.shvSet debug int 1
```

To turn the tracing off again use `kamcmd pv.shvSet debug int 0` and
`kamcmd corex.debug 0`.

### Always visible events

These are logged regardless of the tracing flag: failed SIP authentications
(`[SECURITY-AUTHFAIL]`), scanner user agents (`[SECURITY-SCANNER]`) and SQL
injection attempts (`[SECURITY-SQLI]`), all three meant to be consumed by
CrowdSec, plus addresses blocked by pike, dispatcher failures and request
timeouts without a reply. Malformed SIP requests are logged at debug level:
plenty of devices send them and they are not actionable by themselves.

## Loopback trunks

Some stateless providers reflect an outgoing INVITE back to the proxy when
the called number belongs to the same customer. The caller side and the
callee side of the call then become two local dialogs that share the
From-tag of the initial INVITE.

- topos masks the Call-ID toward the trunks (`mask_callid`), so the reflected
  INVITE does not collide with the outgoing dialog and its rtpengine session.
  topos uses the topoh API for the mask: topoh is loaded with `use_mode` 1,
  as a library only, and its key is `TOPOH_MASK_KEY`.
- Every outgoing INVITE is kept for 30 seconds in the `loopback_pending`
  table. When the reflected INVITE arrives, the two dialogs are linked in the
  `loopback` table.
- In-dialog requests of a linked call (BYE, UPDATE, INFO, PRACK, MESSAGE,
  REFER) go straight to the other side, instead of through the provider.
  Only the Call-ID and the Request-URI are rewritten: the provider relays the
  INVITE and its replies without touching the tags, so From-tag and To-tag are
  already those of the other dialog.
- On BYE, whichever side hangs up, the proxy also closes the leg toward the
  provider with a BYE of its own, as UAC of that leg: the masked Call-ID,
  From and To of the setup with its tags, a CSeq above the last one of the
  caller side, the provider Contact as Request-URI and its route set as
  Route, from the socket the setup used. It is sent with `t_uac_send()`, so
  tm retransmits it for up to `FR_TIMEOUT_BYE` (3 seconds, through the tm
  settings instance `tm[1]`: `t_set_fr()` does not apply to it) and then
  gives up, and it skips topos: it carries no internal address. The proxy
  answers 200 OK to the BYE the provider reflects back and lets the dialog
  module see it, which closes the reflected dialog; a dialog that sees no
  BYE at all expires 2 seconds after the hangup, with the `dlg timeout`
  warning of the dialog module.
- topos rebuilds the end-to-end ACK of a trunk that record-routes with the
  Record-Route as Request-URI. The proxy rebuilds that ACK from the Contact
  of the 2xx and its route set, only when the trunk record-routes: the ACK
  toward an extension, or toward a trunk that does not record-route, follows
  the normal relay.
- The route set used by the rebuilt ACK and by the BYE toward the provider
  is the one of RFC 3261 for the UAC: every Record-Route entry of the 2xx
  that is not the proxy, in reverse order, so a provider with more than one
  record-routing hop gets them all, the nearest first.
- The media of a loopback call goes out and comes back through the public
  address of the node: the provider relays the SDP unchanged, so the
  rtpengine session of one leg sends RTP to the public port of the other.
  Behind NAT this needs hairpin NAT on the router; without it no audio
  reaches either side.
- When the trunk uses SRTP, the reflected SDP is the offer rtpengine made
  for the trunk-out leg, with both SDES and DTLS. The proxy removes the DTLS
  attributes from it (and keeps the offers of the reflected leg on SDES), so
  rtpengine answers with SDES: answered with DTLS, the caller audio was
  dropped as SRTP errors and the callee heard nothing.

Three events are logged at notice level (`KAMAILIO_LOG_LEVEL` 1 or higher):
`event=loopback_detected`, `event=provider_bye_sent` and
`event=provider_bye_absorbed`, all tagged `[LOOPBACK]`. When the data of the
setup are missing the BYE toward the provider is not sent and
`event=provider_bye_skipped` is logged at warning level; when tm cannot send
it (no socket, bad Request-URI) `event=provider_bye_failed` is logged at
warning level. A provider that never answers that BYE leaves no log line. The other lines are
printed only with the debug flag.

Known limit: tools that read the traffic, such as sngrep, see the two legs of
a loopback call with different Call-IDs, masked toward the provider and clear
toward Asterisk, and show them as separate, incomplete dialogs.
