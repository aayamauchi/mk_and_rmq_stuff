#!/bin/sh
#
# Script to monitor Redlist queuesizes on rl-app servers.
#
# Emily Gladstone Cole <emily@ironport.com> 2007-08-16
# 
# Modified to check on status of idle workers 2011-08-19 EGC

# step through and get values for command line arguments
# echo usage if incorrect argument found
while [ $# -gt 0 ]; do
    case "$1" in
    -H)  Host="$2"; shift;;
    -p)  Port="$2"; shift;;
    -w)  Warn="$2"; shift;;
    -c)  Critical="$2"; shift;;
    --) shift; break;;
    *)  break;; # terminate while loop
    esac
    shift
done

# Check for not-set variables that we need to have
if [ "x${Host}" = "x" ] || [ "x${Port}" = "x" ]; then
    echo "usage: $0 -H host
    -p port
    -w WarnQueueLevel
    -c CritQueueLevel
"
    exit 1
fi

# Set Warn and Critical if they're not set
if [ "x${Warn}" = "x" ]; then
    Warn="25"
fi
if [ "x${Critical}" = "x" ]; then
    Critical="5"
fi

WorkerRatio=`wget -q -O - http://${Host}:${Port}/Workers | grep "last status report" | awk '{ print $8 }'`

#BusyWorkers=`echo -n $WorkerRatio | cut -d"/" -f 1`

if [ "x${WorkerRatio}" = "x" ]; then
    echo "OK - not the active blade.  No workers to monitor."
    exit 0
fi

WorkerPool=`wget -q -O - http://${Host}:${Port}/Workers | grep "idle" | grep -v grep | grep -v 150 | wc -l | sed 's/^[ 	]*//g'`

if [ ${WorkerPool} -le ${Critical} ]; then
    echo "CRITICAL - Redlist has less than ${Critical} workers out of 150 idle - currently ${WorkerPool}"
    exit 2
fi
if [ ${WorkerPool} -le ${Warn} ]; then
    echo "WARNING - Redlist has less than ${Warn} workers idle out of 150 - currently ${WorkerPool}"
    exit 1
fi

echo "OK - Redlist currently has ${WorkerPool} workers idle out of 150"

