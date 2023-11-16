# ns8-nethvoice-proxy

NS8 NethVoice proxy module, a SIP and RTP proxy allows multiple instances of
NethVoice to be hosted on the same Node.
The proxy uses Kamailio and rtpengine as core components.

## Module overview

```mermaid

flowchart LR
subgraph Host Network
    subgraph Proxy[NethVoice Proxy Module]
        Kamailio
        RTPengine
    end
    subgraph NethVoice1[NethVoice Module 1]
        Kamailio -- Custom sip ports --> Asterisk1[Asterisk]
        RTPengine -- Custom port range -->Asterisk1[Asterisk]
    end
    subgraph NethVoiceN[NethVoice Module N]
        Kamailio -- Custom sip ports --> AsteriskN[Asterisk]
        RTPengine -- Custom port range -->AsteriskN[Asterisk]
    end
    NethVoice1 -.. N instance of NethVoice Module ..- NethVoiceN
end
sip>SIP Connections]-- Standard SIP ports --> Kamailio
rtp>RTP Flows]-- 10000-20000 --> RTPengine
```

## Install

Instantiate the module with:

    add-module ghcr.io/nethesis/nethvoice-proxy:latest 1

The output of the command will return the instance name.
Output example:

    {"module_id": "nethvoice-proxy1", "image_name": "nethvoice-proxy", "image_url": "ghcr.io/nethesis/nethvoice-proxy:latest"}

## Configure

Let's assume that the nethvoice-proxy instance is named `nethvoice-proxy1`.

Launch `configure-module`, by setting the following parameters:

- `addresses`: configure the IP where the proxy will receive SIP and RTP connections/streams.
  - `address`: IPv4/IPv6 address that is expected to receive VoIP traffic, **mandatory**.
  - `public_address`: public IPV4/IPV6 address that is expected to receive
    VoIP traffic, in case of NAT.

Example:

    api-cli run module/nethvoice-proxy1/configure-module --data '{{"addresses": { "address": "192.168.1.1", "public_address": "1.2.3.4" }}}'

## Uninstall

To uninstall the instance:

    remove-module --no-preserve nethvoice-proxy1

## Testing

Test the module using the `test-module.sh` script:

    ./test-module.sh <NODE_ADDR> ghcr.io/nethesis/nethvoice-proxy:latest

The tests are made using [Robot Framework](https://robotframework.org/)

## Components

### Kamailio

Kamailio® (successor of former OpenSER and SER) is an Open Source SIP Server
released under GPLv2+, able to handle thousands of call setups per second.
Website: [kamailio](https://www.kamailio.org/w/)

### Postgres

PostgreSQL is a powerful, open source object-relational database system with over
35 years of active development that has earned it a strong reputation for
reliability, feature robustness, and performance.
Website: [postgresql](https://www.postgresql.org/)

### Redis

The open source, in-memory data store used by millions of developers as a
database, cache, streaming engine, and message broker.
Website: [redis](https://redis.io/)

### RTPengine

The Sipwise NGCP rtpengine is a proxy for RTP traffic and other UDP based media
traffic. It's meant to be used with the Kamailio SIP proxy and forms a drop-in
replacement for any of the other available RTP and media proxies.
Website: [RTPengine](https://github.com/sipwise/rtpengine)

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

## How to run remotely (DEV or PROD Virtual Machine)

1. Copy in the remote server the `Makefile`
1. Run the `init` stage to creation of `ENV` file and needed folder
   (`only first time`)

   ```bash
   make init
   ```

1. Run all the pods

   ```bash
   make run-all
   ```
