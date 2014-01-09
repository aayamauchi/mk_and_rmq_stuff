#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/nagios/bin:/usr/local/ironport/nagios/bin
HOST=$1
SVC=$2
EVENT=$3
STAT=ops-mon-nagios1.vega.ironport.com

if [[ "$HOST" == "" ]] || [[ "$SVC" == "" ]]
then
    echo "Need host, service, optional event."
    echo "Check long_plugin_output for event (if passed)."
    echo "If passed and match, clear."
    echo "If not passed, just clear."
    exit 3
fi

LONG=`nagiosstatc -s "$STAT"  --query "status service $HOST $SVC long_plugin_output"`
if [[ "$EVENT" == "" ]] || [[ "$LONG" == *$EVENT* ]]
then
    OUT=`nagiosstatc -s "$STAT"  --query "status service $HOST $SVC plugin_output" | awk -F\" '{ print $6 }'`
    # Clear it
    printf "%b" "$HOST\t$SVC\t0\tWas:$OUT\n" | send_nsca -H $STAT -c /usr/local/nagios/etc/send_nsca.cfg

#printf "[%lu] ENABLE_HOST_NOTIFICATIONS;%s\n" ${NOW} ${HOST} > ${FILE}
#printf "[%lu] ENABLE_HOST_SVC_NOTIFICATIONS;%s\n" ${NOW} ${HOST} > ${FILE}

fi
