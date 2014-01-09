#!/bin/sh
# 
# check_snmp_disk_snap.sh 
# written by slindberg while only slightly hungover^H^H^H^H^H^H^H^H whatever
#
# usage: check_snmp_disk_snap.sh <host> <warn> <critical>
if [ $# -lt 3 ]
then
    echo "syntax: $0 <host> <warning> <critical>"
    exit 1
fi

HOST=$1
WARN=$2
ALERT=$3

# grab the disk stuff from the snap server because it doesn't snmp percent full
ACTUAL=`snmpget -v1 -Cf -c y3ll0w\! -Ov $HOST .1.3.6.1.2.1.25.2.3.1.5.2 | cut -f 2 -d" "`
CURR=`snmpget -v1 -Cf -c y3ll0w\! -Ov $HOST .1.3.6.1.2.1.25.2.3.1.6.2 | cut -f 2 -d" "`

# do the fuckin math
RES1=$(echo "scale=2; $CURR / $ACTUAL * 100" | bc)
RES=`echo $RES1 | cut -f 1 -d.`

# warn, alert, OK!
if [ "$RES" -gt "$ALERT" ] ; then
	echo "CRITICAL - disk space is $RES percent full"
        exit 2
fi

if [ "$RES" -gt "$WARN" ] ; then
        echo "WARNING - disk space is $RES percent full"
        exit 1
fi

echo "OK - disk space is $RES percent full"

