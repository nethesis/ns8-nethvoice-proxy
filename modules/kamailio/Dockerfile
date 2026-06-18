FROM ubuntu:24.04

LABEL maintainer="Giovanni Tommasini <giovanni.tommasini@evoseed.io>"

ENV REFRESHED_AT 2024-04-24
ENV TZ="Europe/Rome"

ENV DEBIAN_FRONTEND="noninteractive"
ENV KAMAILIO_VERSION="6.0.7"

RUN apt-get update && apt-get upgrade --no-install-recommends --assume-yes && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install --no-install-recommends --assume-yes ca-certificates gnupg wget && rm -rf /var/lib/apt/lists/*
RUN wget -O- https://deb.kamailio.org/kamailiodebkey.gpg | gpg --dearmor -o /usr/share/keyrings/kamailio.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/kamailio.gpg] http://deb.kamailio.org/kamailio60 noble main" > /etc/apt/sources.list.d/kamailio.list
RUN apt-get update && apt-get install --no-install-recommends --assume-yes \
    kamailio=${KAMAILIO_VERSION}+ubuntu24.04 \
    kamailio-extra-modules=${KAMAILIO_VERSION}+ubuntu24.04 \
    kamailio-json-modules=${KAMAILIO_VERSION}+ubuntu24.04 \
    kamailio-postgres-modules=${KAMAILIO_VERSION}+ubuntu24.04 \
    kamailio-redis-modules=${KAMAILIO_VERSION}+ubuntu24.04 \
    kamailio-tls-modules=${KAMAILIO_VERSION}+ubuntu24.04 \
    kamailio-utils-modules=${KAMAILIO_VERSION}+ubuntu24.04 \
    gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY ./config /etc/kamailio/
COPY ./bootstrap.sh /etc/kamailio/bootstrap.sh
RUN chmod a+x /etc/kamailio/bootstrap.sh

ENTRYPOINT ["/etc/kamailio/bootstrap.sh"]
