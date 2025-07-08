FROM ubuntu:24.04

LABEL maintainer="Giovanni Tommasini <giovanni.tommasini@evoseed.io>"

ENV REFRESHED_AT 2024-04-24
ENV TZ="Europe/Rome"

ENV DEBIAN_FRONTEND="noninteractive"
ENV KAMAILIO_VERSION="5.8.6"

RUN apt-get update && apt-get install --no-install-recommends --assume-yes gnupg wget && rm -rf /var/lib/apt/lists/*
RUN echo "deb http://deb.kamailio.org/kamailio58 focal main" > /etc/apt/sources.list.d/kamailio.list
RUN wget -O- http://deb.kamailio.org/kamailiodebkey.gpg | apt-key add -
RUN apt-get update && apt-get install --no-install-recommends --assume-yes \
    kamailio=${KAMAILIO_VERSION}+ubuntu20.04 \
    kamailio-extra-modules=${KAMAILIO_VERSION}+ubuntu20.04 \
    kamailio-json-modules=${KAMAILIO_VERSION}+ubuntu20.04 \
    kamailio-postgres-modules=${KAMAILIO_VERSION}+ubuntu20.04 \
    kamailio-redis-modules=${KAMAILIO_VERSION}+ubuntu20.04 \
    kamailio-tls-modules=${KAMAILIO_VERSION}+ubuntu20.04 \
    kamailio-utils-modules=${KAMAILIO_VERSION}+ubuntu20.04 \
    gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY ./config /etc/kamailio/
COPY ./bootstrap.sh /etc/kamailio/bootstrap.sh
RUN chmod a+x /etc/kamailio/bootstrap.sh

ENTRYPOINT ["/etc/kamailio/bootstrap.sh"]
