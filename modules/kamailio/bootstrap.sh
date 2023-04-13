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

# rendering the template of kamailio-local.cfg and kamailio.cfg
envsubst < /etc/kamailio/template.kamailio-local.cfg > /tmp/kamailio-local.cfg

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
