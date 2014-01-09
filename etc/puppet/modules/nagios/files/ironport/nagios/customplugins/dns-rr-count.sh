#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

if [ "$3" == "" ]
then
	echo "usage: $0 hostname warn-count crit-count"
	exit 3
fi

x=`echo $2 | grep -q -v "[^0-9]"`
if [ $? -ne 0 ]
then
	echo "warn and crit must be integers"
	exit 3
fi

x=`echo $3 | grep -q -v "[^0-9]"`
if [ $? -ne 0 ]
then
	echo "warn and crit must be integers"
	exit 3
fi

x=`host $1 2>/dev/null >/dev/null`
ce=$?

if [ $ce -ne 0 ]
then
	echo "Unable to resolve $count"
	exit 3
fi

count=`host $1 2>/dev/null| wc -l`

if [ $count -le $3 ]
then
	echo "Only $count entries returned for $1"
	exit 2
elif [ $count -le $2 ]
then
	echo "Only $count entries returned for $1"
	exit 1
else
	echo "$count entries returned for $1"
	exit 0
fi

