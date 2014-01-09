#!/bin/sh
#
# Script to monitor fozzie queue sizes
#

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
if [ x${Host} = x ] || [ x${Port} = x ]; then
    echo "usage: $0 -H host
    -p port
    -w WarnQueueLevel
    -c CritQueueLevel
"
    exit 1
fi

# Set Warn and Critical if they're not set
if [ x${Warn} = x ]; then
    Warn="2000"
fi
if [ x${Critical} = x ]; then
    Critical="5000"
fi

QueueSize=`wget -q -O - http://${Host}:${Port}/queuestat | grep ns | sed 's/ns=//'`

if [ ${QueueSize} -ge ${Critical} ]; then
    echo "CRITICAL - Redlist App queue greater than $Critical - currently ${QueueSize}"
    exit 2
fi
if [ ${QueueSize} -ge ${Warn} ]; then
    echo "WARNING - Redlist App queue greater than ${Warn} - currently ${QueueSize}"
    exit 1
fi
echo "OK - Redlist App queue size currently ${QueueSize}"
