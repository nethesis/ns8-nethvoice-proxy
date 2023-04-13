build:
	cd modules/postgres && make build
	cd modules/redis && make build
	cd modules/rtpengine && make build
	cd modules/kamailio && make build

build-postgres:
	cd modules/postgres && make build

build-redis:
	cd modules/redis && make build

build-rtpengine:
	cd modules/rtpengine && make build

build-kamailio:
	cd modules/kamailio && make build


run:
	cd modules/postgres && make run
	cd modules/redis && make run
	cd modules/rtpengine && make run
	cd modules/kamailio && make run

run-postgres:
	cd modules/postgres && make run

run-redis:
	cd modules/redis && make run

run-rtpengine:
	cd modules/rtpengine && make run

run-kamailio:
	cd modules/kamailio && make run



rebuild-rtpengine:
	docker rm -f rtpengine && make build-rtpengine && make run-rtpengine

rebuild-kamailio:
	docker rm -f kamailio && make build-kamailio && make run-kamailio