#!/bin/sh

PATH=/bin:/usr/bin:/usr/share/cacti/scripts

SECONDS="`date +%s` - `echo "select timestamp from replicationTS" | timeout.pl 5 mysql --connect_timeout=5 -u nagios -pthaxu1T -h $1 sysops | tail -1`"
SECONDS=`echo ${SECONDS} | bc`

echo ${SECONDS}
