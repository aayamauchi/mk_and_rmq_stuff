#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin
HOST=$1


if [[ "$1" == "" ]]
then
    echo "Must supply hostname"
    exit
fi

LOG="syslog1.`echo $HOST | cut -f 2-10 -d.`"
TIMESTAMP=`date +%Y%m%d`

SSH_RET=`ssh -i /var/www/.ssh/id_nagios nagios@${LOG} "tail -q -n 40 /logs/servers/${HOST}/ironport/stat-${TIMESTAMP}.log" 2>/dev/null || echo 'null'`

if [ $SSH_RET != "null" ]; 
then
        awk '{ total+=$16 } { count+=1 } $16 > max { max=$16 } count = 1 { min=$16 } $16 < min { min=$16 } END { printf "avgresponse:%.0f maxresponse:%.0f minresponse:%.0f",(total/count)*1000,(max*1000),(min*1000)}'
else
        printf "avgresponse:0 maxresponse:0 minresponse:0\n"
fi
