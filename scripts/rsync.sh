#!/bin/bash
if [ "$1" != "" -a "$2" != "" ]
then
    read -p "::: rsync to $1, ok [y|Y]? " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        cd ..
        watch -n1 "rsync --rsync-path='sudo rsync' --exclude '.git' --exclude '.vscode' --exclude '.env' -raz --chown $2:$2 --delete $(pwd)/ $1://home/$2/ns8-nethvoice-proxy/"
    fi
else
    echo "Usage: ./rsync.sh <ssh-login-to-server-to-sync> <moduleid> (e.g. ./rsync.sh root@192.168.1.1 nethvoice-proxy2)"
fi
