#!/usr/local/bin/bash

EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNK=3

PATH=/bin:/usr/bin:/usr/local/bin

host=$1
comm=$2
crit=$3
warn=$4

if [[ "$host" == "" || "$comm" == "" ||"$crit" == "" ]]
then
    echo "Please pass host, snmp community, critical threshold in seconds,"
    echo "as well as optional warning threshold."
    echo "If warning threshold not passed, defaults to 2x critical threshold."
    exit $EXIT_UNK
fi


if [ "$warn" == "" ]
then
    warn=`echo "$crit * 2" | bc`
fi

# sysUpTime.0 retuns value in hundredth of seconds.
# so we need to multiple specified thresholds on 100
crit=`echo "$crit * 100" | bc`
warn=`echo "$warn * 100" | bc`

UPTIME=`snmpget -v 2c -c $2 -Ov $1 sysUpTime.0 2>&1`
OUT=$?

if [[ $OUT -ne 0 ]]
then
   echo "Problem retrieving data :: $UPTIME "
   echo "Usually this means the device is either currently rebooting or SNMP is misconfigured."
   exit $EXIT_CRIT
fi

# Handling UNKNOWN OID
# If  next messages are present then exit with UNKNOWN state.
echo $UPTIME | grep -Ei "no such instance|error|no response" > /dev/null
comparison=$?

if [[ $comparison -eq 0 ]]
then
   echo "UNKNOWN. $UPTIME"
   exit $EXIT_UNK
fi

# Calculating UPTIME

TIME=`echo $UPTIME | cut -f2 -d\ | tr -d \(\)`

if [ $TIME -lt $crit ]
then
    echo "CRITICAL. Device's Uptime $TIME is less then $(echo "$crit / 100" | bc) seconds "
    exit $EXIT_CRIT
elif [ $TIME -lt $warn ]
then
    echo "WARNING. Device's Uptime $TIME is less then $(echo "$warn / 100 " | bc) seconds"
    exit $EXIT_WARN
else
    echo "OK. Device's Uptime $(echo "$TIME / 100" | bc) seconds"
    exit $EXIT_OK
fi
