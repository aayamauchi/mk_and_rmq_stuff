#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

if [ "$2" == "" ]
then
    echo "First and second arguments must be warn and crit threshold in seconds."
    echo "Crit must be larger than Warn."
    exit 3
elif [ $2 -lt $1 ]
then
    echo "Critical threshold must be larger than Warning threshold."
    exit 3
fi
warn=$1
crit=$2
user=$3
pass=$4
host=$5

#ssh_cmd='PATH=/bin:/usr/bin;today=`date +%Y%m%d`; yesterday=`date -v -1d +%Y%m%d`; cat /logs/servers/sb-app*/ironport/sb-update-processor-${yesterday}.log /logs/servers/sb-app*/ironport/sb-update-processor-${today}.log | grep "Finished processing log" | sort -M | tail -1'

#line=`ssh nagios@syslog1.soma.ironport.com $ssh_cmd 2>/dev/null`

age=`echo "SELECT UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(MAX(mtime)) FROM senders" |mysql -N -u$user -p$pass -h $host sb`

if [ "${age}" == "" ]
then
    echo "Unexpected error getting max mtime from sb.senders."
    exit 2
else
    if [ $age -gt $crit ]
    then
        echo "SB senders table last updated ${age} seconds ago!"
        exit 2
    elif [ $age -gt $warn ]
    then
        echo "SB senders table last updated ${age} seconds ago!"
        exit 1
    else
        echo "SB senders table last updated ${age} seconds ago."
        exit 0
    fi
fi

echo Monitoring script fellthrough.  Unhandled error!
exit 3
