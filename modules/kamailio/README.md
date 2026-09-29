# Kamailio container

## Environment variables

- `KAMAILIO_LOG_LEVEL` Log level passed to kamailio as `--debug`. Overrides the `debug=` value of the configuration file. Range -3..3, default 1 (notice). Example: "1"
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

## Logging

Log levels: `3` debug, `2` info, `1` notice (default), `0` warning, `-1` error,
down to `-3`. The lower the value, the fewer messages are printed.

### Persistent log level

Set `kamailio_log_level` with the `configure-module` action of the NS8 module.
It writes `KAMAILIO_LOG_LEVEL` in the instance environment, and the container
starts kamailio with `--debug=<value>`, which takes precedence over the
`debug=` value in `kamailio.cfg`. A service restart is required. When the
variable is not set, the value from the configuration file is used.

### Temporary log level, no restart

```
kamcmd corex.debug 3      # raise, to troubleshoot a live issue
kamcmd corex.debug 1      # back to the default
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
`kamcmd corex.debug 1`.

### Always visible events

These are logged regardless of the tracing flag: failed SIP authentications
(`[SECURITY-AUTHFAIL]`, consumed by CrowdSec), addresses blocked by pike,
dispatcher failures, request timeouts without a reply and malformed SIP
requests.
