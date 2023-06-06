default:
	cat Makefile

init:
	mkdir -p ~/pgdata
	chmod 777 ~/pgdata

	@read -p "Inserisci il valore per ENV (DEV|PROD): " ENV; \
	read -p "Inserisci il valore per PUBLIC_IP: " PUBLIC_IP; \
	read -p "Inserisci il valore per SIP_PORT: " SIP_PORT; \
	read -p "Inserisci il valore per POSTGRES_USER: " POSTGRES_USER; \
	read -p "Inserisci il valore per POSTGRES_PASSWORD: " POSTGRES_PASSWORD; \
	read -p "Inserisci il valore per POSTGRES_DB: " POSTGRES_DB; \
	read -p "Inserisci il valore per POSTGRES_HOST: " POSTGRES_HOST; \
	read -p "Inserisci il valore per POSTGRES_PORT: " POSTGRES_PORT; \
	read -p "Inserisci il valore per REDIS_HOST: " REDIS_HOST; \
	read -p "Inserisci il valore per REDIS_PORT: " REDIS_PORT; \
	read -p "Inserisci il valore per KML_SERVER_HEADER: " KML_SERVER_HEADER; \
	read -p "Inserisci il valore per KML_UA_HEADER: " KML_UA_HEADER; \
	read -p "Inserisci il valore per KML_SIP_URL: " KML_SIP_URL; \
	read -p "Inserisci il valore per KML_INTERNAL_NETWORK: " KML_INTERNAL_NETWORK; \
	read -p "Inserisci il valore per RTP_PORT_MIN: " RTP_PORT_MIN; \
	read -p "Inserisci il valore per RTP_PORT_MAX: " RTP_PORT_MAX; \
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
	echo "Il file di configurazione è stato creato con successo."

run-all:
	podman run -d --name postgres -p 127.0.0.1:5432:5432 --env-file=.env -v ~/pgdata:/var/lib/postgresql/data:z ghcr.io/nethesis/nethvoice-proxy-postgres:latest
	podman run -d --name redis --env-file=.env --network host ghcr.io/nethesis/nethvoice-proxy-redis:latest --port 6380
	podman run -d --name rtpengine --env-file=.env --network=host ghcr.io/nethesis/nethvoice-proxy-rtpengine:latest
	echo ":: sleeping 10 seconds for postgres to start before starting kamailio"
	sleep 10
	podman run -d --name kamailio --env-file=.env --network=host ghcr.io/nethesis/nethvoice-proxy-kamailio:latest

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