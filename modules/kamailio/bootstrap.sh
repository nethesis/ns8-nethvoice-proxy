#!/bin/bash
SHM_MEM=512
PKG_MEM=64
FILE=/bootstrap.sh
if test -f "$FILE"; then
    echo "Link already present"
else
    ln -s /etc/kamailio/bootstrap.sh /bootstrap.sh
fi

if [ "$1" == "reload" ]; then
    touch /tmp/dev
    pkill -9 kamailio
    sleep 1
    /bootstrap.sh
fi

# if ${SIP_PORT is not set, set it to 5060
if [ -z "${SIP_PORT}" ]; then
    SIP_PORT=5060
fi
# generating TLS port that is SIP_PORT + 1
TLS_PORT=$(($SIP_PORT + 1))

# removing if present the file /tmp/kamailio-local-additional.cfg
rm -f /tmp/kamailio-local-additional.cfg
# creating empty file /tmp/kamailio-local-additional.cfg
touch /tmp/kamailio-local-additional.cfg

# now I need to handle external interface that could be behind a NAT or not
if [ "${BEHIND_NAT}" == "true" ]; then
    # now I have to add the listen with the advertise address in the kamailio-local-additional.cfg
    echo "listen=udp:${PRIVATE_IP}:${SIP_PORT} advertise ${PUBLIC_IP}:${SIP_PORT}" > /tmp/kamailio-local-additional.cfg
    # doind the same for TCP
    echo "listen=tcp:${PRIVATE_IP}:${SIP_PORT} advertise ${PUBLIC_IP}:${SIP_PORT}" >> /tmp/kamailio-local-additional.cfg
    # doing the same for TLS
    echo "listen=tls:${PRIVATE_IP}:${TLS_PORT} advertise ${PUBLIC_IP}:${TLS_PORT}" >> /tmp/kamailio-local-additional.cfg
else
    # now I have to add the listen with the public IP in the kamailio-local-additional.cfg
    echo "listen=udp:${PUBLIC_IP}:${SIP_PORT}" > /tmp/kamailio-local-additional.cfg
    # doind the same for TCP
    echo "listen=tcp:${PUBLIC_IP}:${SIP_PORT}" >> /tmp/kamailio-local-additional.cfg
    # doing the same for TLS
    echo "listen=tls:${PUBLIC_IP}:${TLS_PORT}" >> /tmp/kamailio-local-additional.cfg
fi

# if SERVICE_IP not set exit with error
if [ -z "${SERVICE_IP}" ]; then
    echo "SERVICE_IP not set"
    exit 1
fi

# adding listen for SERVICE_IP
echo "listen=udp:${SERVICE_IP}:${SIP_PORT}" >> /tmp/kamailio-local-additional.cfg
echo "listen=tcp:${SERVICE_IP}:${SIP_PORT}" >> /tmp/kamailio-local-additional.cfg
echo "listen=tls:${SERVICE_IP}:${TLS_PORT}" >> /tmp/kamailio-local-additional.cfg


# rendering the template of kamailio-local.cfg and kamailio.cfg
envsubst < /etc/kamailio/template.kamailio-local.cfg > /tmp/kamailio-local.cfg
# concatenate the additional configuration
cat /tmp/kamailio-local-additional.cfg >> /tmp/kamailio-local.cfg

# prepare to run kamailio
export PATH_KAMAILIO_CFG=/etc/kamailio/kamailio.cfg
kamailio=$(which kamailio)

# Test the syntax.
$kamailio -f $PATH_KAMAILIO_CFG -c
echo 'Kamailio will be called using the following environment variables:'
echo -n '$DUMP_CORE is: ' ; echo "${DUMP_CORE}"
echo -n '$SHM_MEM is: ' ; echo "${SHM_MEM}"
echo -n '$PKG_MEM is: ' ; echo "${PKG_MEM}"
echo -n '$ENVIRONMENT is: ' ; echo "${ENVIRONMENT}"

# Run kamailio
$kamailio -f $PATH_KAMAILIO_CFG -m "${SHM_MEM}" -M "${PKG_MEM}" -DD -E -e
while [ -f "/tmp/dev" ] || [ "${ENV}" == "dev" ]
  do
    echo "Dev mode!"
    sleep 30
  done
