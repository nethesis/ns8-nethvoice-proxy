#!/bin/bash

# rendering the template 
envsubst < /src/rtpengine.conf.template > /etc/rtpengine/rtpengine.conf

# this only needs to be one once after system (re-) boot
# modprobe xt_RTPENGINE
# iptables -I INPUT -p udp -j RTPENGINE --id 0
# ip6tables -I INPUT -p udp -j RTPENGINE --id 0

# ensure that the table we want to use doesn't exist - usually needed after a daemon
# restart, otherwise will error
# echo 'del 0' > /proc/rtpengine/control

# start rtpengine
$(which rtpengine) -f --config-file=/etc/rtpengine/rtpengine.conf 

while [ -f "/tmp/dev" ]
  do
    echo "Dev mode!"
    sleep 30
  done
