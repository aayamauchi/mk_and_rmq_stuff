#!/bin/bash

if [ $# -eq 0 ] ; then
   echo "no hostname given"
   exit 0
fi

SERVER=$1

RESULT=`curl --silent "http://${SERVER}/counters" | tr -d '\"|\}|\{|\,' | sed -e 's/:dyn:/_dyn:/g' -e 's/:r60:/_r60:/' -e 's/:ts:/_ts:/' -e 's/\./\_/' -e 's/ //g' -e 's/^[ \t]*//;s/[ \t]*$//' -e 's/keymaster_/ /' -e 's/_requests//' -e 's/certificate/cert/' -e 's/counters_//'`

echo $RESULT
