#!/bin/sh
# Run real Kamailio/TOPOS and RTPEngine in a private network namespace.
set -eu

engine=${KAMAILIO_TEST_ENGINE:-podman}
kamailio_image=${KAMAILIO_TEST_IMAGE:-ghcr.io/nethesis/nethvoice-proxy-kamailio:1.7.1}
redis_image=${KAMAILIO_TEST_REDIS_IMAGE:-docker.io/library/redis:7-alpine}
rtpengine_image=${KAMAILIO_TEST_RTPENGINE_IMAGE:-ghcr.io/nethesis/nethvoice-proxy-rtpengine:1.7.1}
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
redis_name="ns8-sip-routing-test-$$"
kamailio_name="ns8-sip-routing-kamailio-$$"
rtpengine_nat_name="ns8-sip-routing-rtp-nat-$$"
rtpengine_public_name="ns8-sip-routing-rtp-public-$$"
certificate_dir=$(mktemp -d)

cleanup() {
    test_status=$?
    if [ "$test_status" -ne 0 ]; then
        "$engine" logs --tail 80 "$rtpengine_nat_name" 2>&1 || true
        "$engine" logs --tail 80 "$rtpengine_public_name" 2>&1 || true
    fi
    "$engine" rm -f "$kamailio_name" >/dev/null 2>&1 || true
    "$engine" rm -f "$rtpengine_nat_name" "$rtpengine_public_name" >/dev/null 2>&1 || true
    "$engine" rm -f "$redis_name" >/dev/null 2>&1 || true
    rm -rf "$certificate_dir"
}
trap cleanup EXIT HUP INT TERM

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost \
    -keyout "$certificate_dir/key.pem" -out "$certificate_dir/cert.pem" 2>/dev/null

"$engine" run --detach --rm --name "$redis_name" --network none \
    --tmpfs /data "$redis_image" \
    redis-server --bind 127.0.0.1 --save '' --appendonly no >/dev/null

# Render the production interface definitions in two daemons. Only control
# ports and media ranges differ so both deployments can share the namespace.
cp "$root/modules/rtpengine/files/rtpengine.conf.template" "$certificate_dir/rtp-nat.template"
sed 's/127.0.0.1:19999/127.0.0.1:29999/;s/127.0.0.1:2224/127.0.0.1:3224/' \
    "$root/modules/rtpengine/files/rtpengine.conf.template" > "$certificate_dir/rtp-public.template"
for deployment in nat public; do
    cat >> "$certificate_dir/rtp-$deployment.template" <<'EOF'
log-stderr = true
log-level = 4
delete-delay = 0
num-threads = 2
EOF
done

"$engine" run --detach --rm --name "$rtpengine_nat_name" --network "container:$redis_name" \
    --security-opt label=disable \
    --volume "$root/modules/rtpengine/bootstrap.sh:/bootstrap.sh:ro" \
    --volume "$certificate_dir/rtp-nat.template:/src/rtpengine.conf.template:ro" \
    --env BEHIND_NAT=true --env PRIVATE_IP=127.10.0.1 --env PUBLIC_IP=127.30.0.1 \
    --env SERVICE_IP=127.20.0.1 --env RTP_PORT_MIN=40000 --env RTP_PORT_MAX=40999 \
    "$rtpengine_image" >/dev/null

"$engine" run --detach --rm --name "$rtpengine_public_name" --network "container:$redis_name" \
    --security-opt label=disable \
    --volume "$root/modules/rtpengine/bootstrap.sh:/bootstrap.sh:ro" \
    --volume "$certificate_dir/rtp-public.template:/src/rtpengine.conf.template:ro" \
    --env BEHIND_NAT=false --env PUBLIC_IP=127.30.0.1 \
    --env SERVICE_IP=127.20.0.1 --env RTP_PORT_MIN=41000 --env RTP_PORT_MAX=41999 \
    "$rtpengine_image" >/dev/null

"$engine" run --rm --name "$kamailio_name" --network "container:$redis_name" \
    --security-opt label=disable --volume "$root:/src:ro" \
    --volume "$root/modules/kamailio/config:/etc/kamailio:ro" \
    --volume "$root/modules/kamailio/bootstrap.sh:/bootstrap.sh:ro" \
    --volume "$certificate_dir:/test-certs:ro" --env SIP_TEST_CERTIFICATE_DIR=/test-certs \
    --env SIP_TEST_ISOLATED=1 \
    --env PYTHONDONTWRITEBYTECODE=1 \
    --workdir /src/tests --entrypoint python3 "$kamailio_image" \
    -m unittest -v test_sip_socket_routing test_rtp_routing
