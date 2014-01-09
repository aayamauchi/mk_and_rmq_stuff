#!/bin/sh
# 
# case_ini_pubtime.sh
# 
# Emily Gladstone Cole (egladsto@cisco.com) 9/3/09
# https://it-tickets.ironport.com/Ticket/Display.html?id=107115
# Get a file from downloads and make sure last publish time is current
# 
# Usage:
# case_ini_pubtime.sh -u URL -s STRING -w WARN -c CRITICAL

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin

# step through and get values for command line arguments
# echo usage if incorrect argument found
while [ $# -gt 0 ]; do
    case "$1" in
    -u)  URL="$2"; shift;;
    -s)  String="$2"; shift;;
    -w)  Warn="$2"; shift;;
    -c)  Critical="$2"; shift;;
    --)	shift; break;;
    -*)
        echo >&2 \
        "usage: $0 -u URL -s STRING -w WARN -c CRITICAL"
        exit 1;;
    *)  break;;	# terminate while loop
    esac
    shift
done

# Exit if user did not define an URL to retrieve
if [ x${URL} = x ]; then
    echo "You must specify an URL to retrieve!"
    echo "usage: $0 -u URL -s STRING -w WARN -c CRITICAL"
    exit 3
fi

# Get the URL, just to make sure it's accessible, before trying to do
# anything else with parsing
wget -q -O - ${URL} 1>/dev/null 2>/dev/null

# Exit if URL couldn't be retrieved
if [ $? -ne 0 ]; then
  echo "UNKNOWN - plugin didn't download and parse ${URL} correctly."
  exit 3
fi

NonEpochDate=`wget -q -O - ${URL} | grep -A 1 ${String} | tail -1 | cut -d" " -f 3`

Date=${NonEpochDate%%_*}
Time=${NonEpochDate##*_}
Hour=${Time%[0-9][0-9][0-9][0-9]}
Foo=${Time#[0-9][0-9]}
Minutes=${Foo%[0-9][0-9]}
Seconds=${Time#[0-9][0-9][0-9][0-9]}
if `uname -s | grep Linux 1>/dev/null 2>/dev/null`; then
   EpochDate=`date +%s --date "${Date} ${Hour}:${Minutes}:${Seconds}"`
else
   EpochDate=`date -j -f "%Y%m%d %T" "${Date} ${Hour}:${Minutes}:${Seconds}" "+%s"`
fi
Now=`date +%s`

TimeDiff=`expr $Now - $EpochDate`

# Set fallback ExitStatus and ExitMessage
ExitStatus=3
ExitMessage="UNKNOWN - plugin didn't download and parse ${URL} correctly."

if [ $TimeDiff -gt $Critical ]; then
  # We're at critical
  ExitStatus=2
  ExitMessage="CRITICAL - ${String} publish age is $TimeDiff seconds.  Critical is $Critical seconds!"
else
  if [ $TimeDiff -gt $Warn ]; then
    # We're at Warn
    ExitStatus=1
    ExitMessage="WARNING - ${String} publish age is $TimeDiff seconds.  Warn is $Warn seconds!"
  else
    # We're OK
    ExitStatus=0
    ExitMessage="OK - ${String} publish age is $TimeDiff seconds.  Warn is $Warn seconds."
  fi
fi

echo "$ExitMessage"
exit $ExitStatus

