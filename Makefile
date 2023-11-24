default:
	cat Makefile

init:
	@runagent -c python3 ./scripts/ns8_setenv.py ENV
	@runagent -c python3 ./scripts/ns8_setenv.py PUBLIC_IP
	@runagent -c python3 ./scripts/ns8_setenv.py KML_SERVER_HEADER
	@runagent -c python3 ./scripts/ns8_setenv.py KML_UA_HEADER
	@runagent -c python3 ./scripts/ns8_setenv.py KML_SIP_URL
	@runagent -c python3 ./scripts/ns8_setenv.py KML_INTERNAL_NETWORK

run-all:
	runagent bash -c 'podman run -d --name postgres -p 127.0.0.1:$$POSTGRES_PORT:5432 --env-file ~/.config/state/environment --volume=pgdata:/var/lib/postgresql/data ghcr.io/nethesis/nethvoice-proxy-postgres:latest'
	runagent bash -c 'podman run -d --name redis --publish=127.0.0.1:$$REDIS_PORT:6379 --env-file ~/.config/state/environment ghcr.io/nethesis/nethvoice-proxy-redis:latest'
	podman run -d --name rtpengine --env-file ~/.config/state/environment --network=host ghcr.io/nethesis/nethvoice-proxy-rtpengine:latest
	echo ":: sleeping 10 seconds for postgres to start before starting kamailio"
	sleep 10
	podman run -d --name kamailio --env-file ~/.config/state/environment --network=host \
		-v ~/.config/state/selfsigned.pem:/etc/kamailio/cert.pem:z \
		-v ~/.config/state/kamailio-certificates:/etc/kamailio/tls:Z \
		ghcr.io/nethesis/nethvoice-proxy-kamailio:latest


run-kamailio-dev:
	podman stop kamailio || exit 0
	podman rm kamailio || exit 0
	podman run -d --name kamailio --env-file ~/.config/state/environment --network=host \
		-v ~/.config/state/selfsigned.pem:/etc/kamailio/cert.pem:z \
		-v ~/.config/state/kamailio-certificates:/etc/kamailio/tls:Z \
		-v ./modules/kamailio/config/kamailio.cfg:/etc/kamailio/kamailio.cfg:z \
		-v ./modules/kamailio/config/template.kamailio-local.cfg:/etc/kamailio/template.kamailio-local.cfg:z \
		ghcr.io/nethesis/nethvoice-proxy-kamailio:latest

log:
	podman logs -f --tail=20 kamailio redis rtpengine postgres

stop-all:
	podman stop kamailio redis rtpengine postgres

clean-all:
	podman rm -f kamailio redis rtpengine postgres

start-all:
	podman start kamailio redis rtpengine postgres

restart-all:
	podman restart kamailio redis rtpengine postgres
