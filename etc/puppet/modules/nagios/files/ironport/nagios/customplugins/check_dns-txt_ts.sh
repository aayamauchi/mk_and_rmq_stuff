#!/usr/local/bin/bash

HOST=$1
shift
ENTRY=$1
shift
WARN=$1
shift
CRIT=$1

if [ "$WARN" == "" ]
then
	echo "Need warning threshold"
	exit 3
elif [ "$CRIT" == "" ]
then
	echo "Need critical threshold"
	exit 3
elif [ $CRIT -lt $WARN ]
then
	echo "Warn must be less than Crit"
	exit 3
fi

DATE=`/bin/date +%s`
TS=`/usr/bin/dig @${HOST} -t txt +short ${ENTRY} 2>/dev/null`
if [ $? -ne 0 ]
then
	echo "Error running dig"
	exit 2
fi
TS=`/bin/echo ${TS} | /usr/bin/tr -d \"`

RANGE=`/bin/echo ${DATE} - ${TS} | /usr/bin/bc`

if [ ${RANGE} -gt ${CRIT} ]
then
	echo "$ENTRY is $RANGE seconds old"
	exit 2
elif [ ${RANGE} -gt ${WARN} ]
then
	echo "$ENTRY is $RANGE seconds old"
	exit 1
else
	echo "$ENTRY is $RANGE seconds old"
	exit 0
fi

