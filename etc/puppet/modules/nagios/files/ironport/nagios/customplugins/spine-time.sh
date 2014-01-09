#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

spine=`ssh nagios@$1 "cat /usr/share/cacti/log/spine.stat /usr/share/cacti/spine.id" 2>/dev/null`

time=`echo $spine | cut -f1 -d\  | cut -f2 -d: | cut -f1 -d.`
id=`echo $spine | cut -f3 -d\ `

if [ "$time" == "" ]
then
    echo "Spine stats collection error."
    exit 3
fi
echo "Spine runtime $time/296 seconds on poller id $id."
if [ $time -gt 270 ]
then
    exit 2
elif [ $time -gt 250 ]
then
    exit 1
else
    exit 0
fi
