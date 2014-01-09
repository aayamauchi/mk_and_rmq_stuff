#!/usr/local/bin/bash

if [ $# -lt 4 ]
then
    echo "syntax: $0 <host> <directory> <warning> <critical>"
    exit 1
fi

COUNT=`/usr/bin/ssh -i ~nagios/.ssh/id_rsa -o StrictHostKeyChecking=no nagios@$1 "/bin/ls $2 | wc -w" 2>&1 | head -1`

if [ "${COUNT}" -eq "${COUNT}" ] 2>/dev/null
then

if [ ${COUNT} -gt $4 ]
then
    echo "CRITICAL - $1:$2 filecount $COUNT gt $4"
    exit 2
elif [ ${COUNT} -gt $3 ]
then
    echo "WARNING - $1:$2 filecount $COUNT gt $3"
    exit 1
else
    echo "OK - $1:$2 filecount $COUNT"
    exit 0
fi

else
echo "CRITICAL - $1:$2 unexepected error $COUNT" | head -1
exit 2
fi

