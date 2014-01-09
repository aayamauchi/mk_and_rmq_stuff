#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/customplugins

if [ "$NAGIOS_HOSTNAME" == "" ]
then
    NAGIOS__HOSTALERTEMAIL=$1
    ARGS=$2
fi

if [ "${NAGIOS__HOSTALERTEMAIL}" != "" ]
then
    if [[ "${ARGS}" == *"service"* ]]
    then
        TMPL="default-nopw"
    else
        TMPL="default-host-nopw"
    fi
    notification_feeder.py -t ${TMPL} -c "${NAGIOS__HOSTALERTEMAIL}" --noenv -m "$ARGS"
fi
