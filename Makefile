default:
	cat Makefile
init:
	mkdir -p ~/pgdata
	chmod 777 ~/pgdata
run-all:
	podman run -d --name postgres \
	-p 127.0.0.1:5432:5432 \
	--env-file=.env\
	-v ~/pgdata:/var/lib/postgresql/data:z \
	ghcr.io/nethesis/nethvoice-proxy-postgres:latest
	podman run -d --name redis --env-file=.env --publish=127.0.0.1:6380:6379 ghcr.io/nethesis/nethvoice-proxy-redis:latest
	podman run -d --name rtpengine --env-file=.env --network=host ghcr.io/nethesis/nethvoice-proxy-rtpengine:latest
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