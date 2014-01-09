#!/bin/sh
export CURDATE=`/bin/date +%s`
export RTYPE="txt"

help ( ) {
  echo "syntax $0 <hostname> <ip> <query_domain> <max_diff>"
  exit 1
}

if [ ! $2 ]
then
  help
  exit 1
fi

if [ ! $4 ]
then
  MAX=30
else
  MAX=$4
fi

export MAX
export HOST=$1
export Q=$3
export IP=$2

TESTIP=`echo $2 | cut -d'.' -f 4`
if [ ! $TESTIP ]
then
  help
fi

BLAH=`echo $IP`
REV=`echo $IP | awk {'split($1,ip,"."); { print ip[4]"."ip[3]"."ip[2]"."ip[1];'}}` ;  REV1=`echo $REV | awk {'print $2'}`
export REV

export UPDATE=`dig @$HOST -p 53 -t $RTYPE $REV.$Q.senderbase.org | cut -d '|' -f 11 | grep "9=" | cut -d '=' -f 2 | cut -d '.' -f 1`
export DIFF=`expr $CURDATE - $UPDATE`
if [ $DIFF -gt $MAX ]
then
  echo "WARNING: $DIFF > $MAX"
  exit 1
else
  echo "OK: $DIFF less than $MAX"
fi

