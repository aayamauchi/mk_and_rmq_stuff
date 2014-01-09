#!/usr/local/bin/bash

NSCANUM=`/bin/ps aux | grep nsca | wc -l`

if [ ${NSCANUM} -gt 60 ]
then
  for x in `ps aux | grep nsca | grep nagios | grep -v grep | awk '{ print $2 }' | head -50`
  do
    kill -9 $x
  done
fi
