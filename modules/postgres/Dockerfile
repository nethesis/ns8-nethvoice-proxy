FROM postgres:17

LABEL maintainer="Giovanni Tommasini <giovanni.tommasini@evoseed.io>"

ENV REFRESHED_AT 2023-04-01
ENV TZ="Europe/Rome"

ADD migrations /docker-entrypoint-initdb.d/
