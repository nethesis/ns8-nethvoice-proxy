#!/bin/sh
# Run real Kamailio/TOPOS in a private network namespace containing only Redis.
set -eu

engine=${KAMAILIO_TEST_ENGINE:-podman}
kamailio_image=${KAMAILIO_TEST_IMAGE:-ghcr.io/nethesis/nethvoice-proxy-kamailio:1.7.1}
redis_image=${KAMAILIO_TEST_REDIS_IMAGE:-docker.io/library/redis:7-alpine}
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
redis_name="ns8-sip-routing-test-$$"
kamailio_name="ns8-sip-routing-kamailio-$$"
certificate_dir=$(mktemp -d)

cleanup() {
    "$engine" rm -f "$kamailio_name" >/dev/null 2>&1 || true
    "$engine" rm -f "$redis_name" >/dev/null 2>&1 || true
    rm -rf "$certificate_dir"
}
trap cleanup EXIT HUP INT TERM

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost \
    -keyout "$certificate_dir/key.pem" -out "$certificate_dir/cert.pem" 2>/dev/null

"$engine" run --detach --rm --name "$redis_name" --network none \
    --tmpfs /data "$redis_image" \
    redis-server --bind 127.0.0.1 --save '' --appendonly no >/dev/null

"$engine" run --rm --name "$kamailio_name" --network "container:$redis_name" \
    --security-opt label=disable --volume "$root:/src:ro" \
    --volume "$root/modules/kamailio/config:/etc/kamailio:ro" \
    --volume "$root/modules/kamailio/bootstrap.sh:/bootstrap.sh:ro" \
    --volume "$certificate_dir:/test-certs:ro" --env SIP_TEST_CERTIFICATE_DIR=/test-certs \
    --env SIP_TEST_ISOLATED=1 \
    --workdir /src --entrypoint python3 "$kamailio_image" \
    tests/test_sip_socket_routing.py
