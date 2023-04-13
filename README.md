# nethvoice-proxy

## Folder Structure

```bash
.
├── CHANGELOG.md
├── LICENSE
├── Makefile
├── README.md
└── modules
    ├── kamailio
    │   ├── Dockerfile
    │   ├── Makefile
    │   ├── bootstrap.sh
    │   └── config
    │       ├── kamailio.cfg
    │       └── template.kamailio-local.cfg
    ├── postgres
    │   ├── Dockerfile
    │   ├── Makefile
    │   └── migrations
    │       ├── 01_init_kamailio_db.sql
    │       ├── 02_insert_data_version.sql
    │       └── 03_insert_data_rtpengine.sql
    ├── redis
    │   ├── Dockerfile
    │   ├── Makefile
    │   └── redis.conf
    └── rtpengine
        ├── Dockerfile
        ├── Makefile
        ├── bootstrap.sh
        └── files
            ├── libbcg729-0_1.0.4+git20180222-0.1_bpo9+1_amd64.deb
            ├── libbcg729-dev_1.0.4+git20180222-0.1_bpo9+1_amd64.deb
            ├── ngcp-rtpengine-daemon
            └── rtpengine.conf.template
```

---

## Components

### Kamailio

Kamailio® (successor of former OpenSER and SER) is an Open Source SIP Server released under GPLv2+, able to handle thousands of call setups per second
Website: [kamailio](https://www.kamailio.org/w/)

### Postgres

PostgreSQL is a powerful, open source object-relational database system with over 35 years of active development that has earned it a strong reputation for reliability, feature robustness, and performance.
Website: [postgresql](https://www.postgresql.org/)

### Redis

The open source, in-memory data store used by millions of developers as a database, cache, streaming engine, and message broker.
Website: [redis](https://redis.io/)

### RTPengine

The Sipwise NGCP rtpengine is a proxy for RTP traffic and other UDP based media traffic. It's meant to be used with the Kamailio SIP proxy and forms a drop-in replacement for any of the other available RTP and media proxies.
Website: [RTPengine](https://github.com/sipwise/rtpengine)

---

## How to run locally

1. Compile the .env

    ```bash
    cp .env.template .env
    ```

    Edit the .env file and set the correct values

1. Build the docker image and run it

    ```bash
    cd modules/postgres
    make build
    make run && make log

    cd modules/redis
    make build
    make run && make log

    cd modules/rtpengine
    make build
    make run && make log

    cd modules/kamailio
    make build
    make run && make log
    ```
