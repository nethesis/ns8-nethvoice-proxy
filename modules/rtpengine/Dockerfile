FROM ubuntu:22.04

LABEL maintainer="Giovanni Tommasini <giovanni.tommasini@evoseed.io>"

ENV REFRESHED_AT 2023-03-25
ENV TZ="Europe/Rome"

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get -qq update \
    && apt-get -qq --no-install-recommends install \
    debhelper \
    ca-certificates \
    libxtables-dev \
    libcurl4-openssl-dev \
    libpcre3-dev \
    libxmlrpc-core-c3-dev \
    markdown libavfilter-dev \
    libavformat-dev \
    libevent-dev \
    libglib2.0-dev \
    libhiredis-dev \
    libjson-glib-dev \
    libpcap0.8-dev \
    libpcap-dev \
    libssl-dev \
    dkms \
    module-assistant \
    nfs-common \
    libb-hooks-op-check-perl \
    libexporter-tidy-perl \
    libbencode-perl \
    libcrypt-rijndael-perl \
    libdigest-hmac-perl \
    libio-socket-inet6-perl \
    libsocket6-perl \
    default-libmysqlclient-dev \
    gperf \
    libcrypt-openssl-rsa-perl \
    libdigest-crc-perl \
    libio-multiplex-perl \
    libiptc-dev \
    libnet-interface-perl \
    libspandsp-dev \
    libsystemd-dev \
    libwebsockets-dev \
    libmosquitto-dev \
    libconfig-tiny-perl \
    libjson-perl \
    python3-websockets \
    libopus-dev \
    pbuilder \
    build-essential \
    git \
    iptables \
    libmysqlclient-dev \
    default-libmysqlclient-dev \
    libcurl4-openssl-dev \
    jq \
    mtr-tiny \
    netcat \
    net-tools \
    traceroute

RUN rm -Rf /src \
    && mkdir /src && cd /src \
    && git clone --branch mr11.2 https://github.com/sipwise/rtpengine.git

# https://deb.sipwise.com/spce/mr6.2.1/pool/main/b/bcg729/
# https://deb.sipwise.com/spce/mr6.2.1/pool/main/b/bcg729/libbcg729-0_1.0.4+git20180222-0.1~bpo9+1_amd64.deb
# https://deb.sipwise.com/spce/mr6.2.1/pool/main/b/bcg729/libbcg729-dev_1.0.4+git20180222-0.1~bpo9+1_amd64.deb
COPY ./files /src
RUN cd /src \
    && dpkg -i libbcg729-0_1.0.4+git20180222-0.1_bpo9+1_amd64.deb \
    && dpkg -i libbcg729-dev_1.0.4+git20180222-0.1_bpo9+1_amd64.deb \
    && rm libbcg729-0_1.0.4+git20180222-0.1_bpo9+1_amd64.deb \
    && rm libbcg729-dev_1.0.4+git20180222-0.1_bpo9+1_amd64.deb

RUN rm -rf /var/lib/apt/lists/*

RUN cd /src/rtpengine/ \
    && dpkg-checkbuilddeps \
    && DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage --no-sign

RUN cd /src/ \
 && dpkg -i *.deb

COPY ./bootstrap.sh /bootstrap.sh
RUN chmod +x /bootstrap.sh

ENTRYPOINT ["/bootstrap.sh"]
