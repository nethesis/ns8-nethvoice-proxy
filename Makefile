default:
	cat Makefile
init:
	mkdir -p ~/pgdata
	chmod 777 ~/pgdata
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