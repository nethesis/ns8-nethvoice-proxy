# CrowdSec integration (reference / manual install)

kamailio logs failed SIP authentication attempts (REGISTER/INVITE rejected
by the backend Asterisk with 401/403/407 after credentials were offered) as
a structured line, e.g.:

```
[SECURITY-AUTHFAIL] <call-id> REGISTER-1 - event=auth_failure method=REGISTER status=403 src_ip=203.0.113.7 user=1001 callid=<call-id>
```

This directory ships a CrowdSec parser + scenario pair that turns those
lines into bans, mirroring the built-in `crowdsecurity/asterisk_bf`
collection already used elsewhere in NS8.

**Scope note**: `ns8-crowdsec` has no automated mechanism today for another
module to push a custom parser/scenario into a running `crowdsec1` instance.
Installing these files is a manual, per-cluster admin step — it is not
applied automatically when `nethvoice-proxy` is installed or upgraded.

## Install on a `crowdsec1` instance

1. Copy both YAML files into the instance's local config tree:

   ```
   scp kamailio-logs.yaml root@<node>:/var/lib/nethserver/crowdsec1/state/crowdsec_config/parsers/s01-parse/
   scp kamailio_bf.yaml   root@<node>:/var/lib/nethserver/crowdsec1/state/crowdsec_config/scenarios/
   ```

   Verify the exact stage/subdirectory names match your `crowdsec1` version
   with `podman exec crowdsec1 cscli parsers list` / `cscli scenarios list`
   before copying, since hub layout can change between releases.

2. Reload crowdsec so it picks up the new parser/scenario:

   ```
   runagent -m crowdsec1 podman exec crowdsec1 cscli hub update
   runagent -m crowdsec1 systemctl --user restart crowdsec1
   ```

3. Verify it's active and receiving events:

   ```
   podman exec crowdsec1 cscli parsers list | grep kamailio
   podman exec crowdsec1 cscli scenarios list | grep kamailio
   podman exec crowdsec1 cscli metrics
   ```

4. Trigger a failed login against kamailio (wrong password on a REGISTER)
   and confirm an alert/decision appears:

   ```
   podman exec crowdsec1 cscli alerts list
   ```

5. No extra wiring is needed for enforcement: `crowdsec1-firewall-bouncer`
   acts on any decision from `crowdsec1` regardless of which scenario
   produced it.
