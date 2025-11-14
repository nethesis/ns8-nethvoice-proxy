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

# If arguments are provided but first is not "reload", execute them
if [ $# -gt 0 ]; then
    exec "$@"
fi

# removing if present the file /tmp/kamailio-local-additional.cfg
rm -f /tmp/kamailio-local-additional.cfg
# creating empty file /tmp/kamailio-local-additional.cfg
touch /tmp/kamailio-local-additional.cfg

# now I need to handle external interface that could be behind a NAT or not
if [ "${BEHIND_NAT}" == "true" ]; then
    # now I have to add the listen with the advertise address in the kamailio-local-additional.cfg
    echo "listen=udp:${PRIVATE_IP}:5060 advertise ${PUBLIC_IP}:5060" > /tmp/kamailio-local-additional.cfg
    # doind the same for TCP
    echo "listen=tcp:${PRIVATE_IP}:5060 advertise ${PUBLIC_IP}:5060" >> /tmp/kamailio-local-additional.cfg
    # doing the same for TLS
    echo "listen=tls:${PRIVATE_IP}:5061 advertise ${PUBLIC_IP}:5061" >> /tmp/kamailio-local-additional.cfg
else
    # now I have to add the listen with the public IP in the kamailio-local-additional.cfg
    echo "listen=udp:${PUBLIC_IP}:5060" > /tmp/kamailio-local-additional.cfg
    # doind the same for TCP
    echo "listen=tcp:${PUBLIC_IP}:5060" >> /tmp/kamailio-local-additional.cfg
    # doing the same for TLS
    echo "listen=tls:${PUBLIC_IP}:5061" >> /tmp/kamailio-local-additional.cfg
fi

# if SERVICE_IP not set exit with error
if [ -z "${SERVICE_IP}" ]; then
    echo "SERVICE_IP not set"
    exit 1
fi

# adding listen for SERVICE_IP
echo "listen=udp:${SERVICE_IP}:5060" >> /tmp/kamailio-local-additional.cfg
echo "listen=tcp:${SERVICE_IP}:5060" >> /tmp/kamailio-local-additional.cfg
echo "listen=tls:${SERVICE_IP}:5061" >> /tmp/kamailio-local-additional.cfg

# Generate trunk port slots if TRUNK_SLOTS is set and > 0
if [ -n "${TRUNK_SLOTS}" ] && [ "${TRUNK_SLOTS}" -gt 0 ]; then
    TRUNK_PORT_START=${TRUNK_PORT_START:-5071}

    echo "# Trunk Port Slots for Multi-Trunk Support" >> /tmp/kamailio-local-additional.cfg
    echo "Generating ${TRUNK_SLOTS} trunk slots starting at port ${TRUNK_PORT_START}"

    for i in $(seq 1 ${TRUNK_SLOTS}); do
        SLOT_NAME="slot${i}"
        SLOT_PORT=$((TRUNK_PORT_START + i - 1))

        if [ "${BEHIND_NAT}" == "true" ]; then
            # NAT mode: bind to private IP, advertise public IP
            echo "listen=udp:${PRIVATE_IP}:${SLOT_PORT} advertise ${PUBLIC_IP}:${SLOT_PORT} name \"${SLOT_NAME}\"" >> /tmp/kamailio-local-additional.cfg
            echo "listen=tcp:${PRIVATE_IP}:${SLOT_PORT} advertise ${PUBLIC_IP}:${SLOT_PORT} name \"${SLOT_NAME}\"" >> /tmp/kamailio-local-additional.cfg
            echo "listen=tls:${PRIVATE_IP}:$((SLOT_PORT + 1000)) advertise ${PUBLIC_IP}:$((SLOT_PORT + 1000)) name \"${SLOT_NAME}\"" >> /tmp/kamailio-local-additional.cfg
        else
            # Direct mode: bind to public IP
            echo "listen=udp:${PUBLIC_IP}:${SLOT_PORT} name \"${SLOT_NAME}\"" >> /tmp/kamailio-local-additional.cfg
            echo "listen=tcp:${PUBLIC_IP}:${SLOT_PORT} name \"${SLOT_NAME}\"" >> /tmp/kamailio-local-additional.cfg
            echo "listen=tls:${PUBLIC_IP}:$((SLOT_PORT + 1000)) name \"${SLOT_NAME}\"" >> /tmp/kamailio-local-additional.cfg
        fi

        echo "Generated slot: ${SLOT_NAME} on port ${SLOT_PORT} (UDP/TCP), $((SLOT_PORT + 1000)) (TLS)"
    done
fi


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
if [ -f "/tmp/dev" ] || [ "${ENV}" == "dev" ]; then
    echo "Dev mode!"
    $kamailio -f $PATH_KAMAILIO_CFG -m "${SHM_MEM}" -M "${PKG_MEM}" -DD -E -e
else
    #Allow kamailio to handle SIGTERM from podman stop
    exec $kamailio -f $PATH_KAMAILIO_CFG -m "${SHM_MEM}" -M "${PKG_MEM}" -DD -E -e
fi

while [ -f "/tmp/dev" ] || [ "${ENV}" == "dev" ]
  do
    echo "Dev mode!"
    sleep 30
  done
