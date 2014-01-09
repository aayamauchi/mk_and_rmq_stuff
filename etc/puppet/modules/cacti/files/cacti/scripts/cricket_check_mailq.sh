#!/bin/sh
#
# checks the mailq on specific system

if [ $1 = "-H" ]
then
   HOST=$2
else
   echo "usage: ./cricket_check_mailq.sh -H <host> "
   echo "assumes there is ssh trust between servers"
   exit 1
fi

# added to get past sc-app mailq issues
#echo "NaN"
#exit 0

LIST=`ssh cricket@$HOST "mailq | tail -1"`
CUT=`echo $LIST | cut -f 5 -d " "`
echo $CUT
