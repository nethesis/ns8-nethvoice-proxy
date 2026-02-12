FROM redis:8.6

LABEL maintainer="Giovanni Tommasini <giovanni.tommasini@evoseed.io>"

ENV REFRESHED_AT 2023-03-25
ENV TZ="Europe/Rome"

COPY redis.conf /usr/local/etc/redis/redis.conf
CMD [ "redis-server", "/usr/local/etc/redis/redis.conf" ]