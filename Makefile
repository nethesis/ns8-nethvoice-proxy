default:
	cat Makefile

init:
	@read -p "Insert value for per ENV (DEV|PROD): " ENV; \
	read -p "Insert value for PUBLIC_IP: " PUBLIC_IP; \
	read -p "Insert value for SIP_PORT: " SIP_PORT; \
	read -p "Insert value for POSTGRES_USER: " POSTGRES_USER; \
	read -p "Insert value for POSTGRES_PASSWORD: " POSTGRES_PASSWORD; \
	read -p "Insert value for POSTGRES_DB: " POSTGRES_DB; \
	read -p "Insert value for POSTGRES_HOST: " POSTGRES_HOST; \
	read -p "Insert value for POSTGRES_PORT: " POSTGRES_PORT; \
	read -p "Insert value for REDIS_HOST: " REDIS_HOST; \
	read -p "Insert value for REDIS_PORT: " REDIS_PORT; \
	read -p "Insert value for KML_SERVER_HEADER: " KML_SERVER_HEADER; \
	read -p "Insert value for KML_UA_HEADER: " KML_UA_HEADER; \
	read -p "Insert value for KML_SIP_URL: " KML_SIP_URL; \
	read -p "Insert value for KML_INTERNAL_NETWORK: " KML_INTERNAL_NETWORK; \
	read -p "Insert value for RTP_PORT_MIN: " RTP_PORT_MIN; \
	read -p "Insert value for RTP_PORT_MAX: " RTP_PORT_MAX; \
	echo "ENV=$$ENV" > .env; \
	echo "PUBLIC_IP=$$PUBLIC_IP" >> .env; \
	echo "SIP_PORT=$$SIP_PORT" >> .env; \
	echo "POSTGRES_USER=$$POSTGRES_USER" >> .env; \
	echo "POSTGRES_PASSWORD=$$POSTGRES_PASSWORD" >> .env; \
	echo "POSTGRES_DB=$$POSTGRES_DB" >> .env; \
	echo "POSTGRES_HOST=$$POSTGRES_HOST" >> .env; \
	echo "POSTGRES_PORT=$$POSTGRES_PORT" >> .env; \
	echo "REDIS_HOST=$$REDIS_HOST" >> .env; \
	echo "REDIS_PORT=$$REDIS_PORT" >> .env; \
	echo "KML_SERVER_HEADER=$$KML_SERVER_HEADER" >> .env; \
	echo "KML_UA_HEADER=$$KML_UA_HEADER" >> .env; \
	echo "KML_SIP_URL=$$KML_SIP_URL" >> .env; \
	echo "KML_INTERNAL_NETWORK=$$KML_INTERNAL_NETWORK" >> .env; \
	echo "RTP_PORT_MIN=$$RTP_PORT_MIN" >> .env; \
	echo "RTP_PORT_MAX=$$RTP_PORT_MAX" >> .env; \
	echo "Configuration file write successfully."

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
