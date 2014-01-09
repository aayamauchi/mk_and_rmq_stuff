#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

TAIL=`ssh -o PasswordAuthentication=no -o ConnectTimeout=2 $1 "tail -4 /var/log/messages | grep 'nfs_getpages: error 70'" 2>/dev/null`

if [ "${TAIL}" != "" ]
then
    echo "Stale NFS handle on Blade host."
    printf "%b" "${TAIL}"
    exit 2
else
    echo "OK"
    exit 0
fi

