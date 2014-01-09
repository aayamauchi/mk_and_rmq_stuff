#!/bin/sh
#
# Basic script by Tim Spencer <tspencer@ironport.com>
# Thu Mar  2 21:08:22 PST 2006
#
# Expanded and error/argument checking added 7/13/07
# Emily Gladstone Cole <emily@ironport.com>
#
# you can find out the args for this by doing something like this:
# snmpwalk -c <rocommstring> -v 2c HOST | grep PID
#  Where HOST is the name of the host that it's running on
#  And PID is the pid of the process (previously gathered with ps)
# Then look at the hrSWRunName for the process, and the
# hrSWRunParameters for the arguments.  Have fun!
#

PATH=/bin:/usr/bin:/usr/local/bin
# step through and get values for command line arguments
# echo usage if incorrect argument found
while [ $# -gt 0 ]; do
    case "$1" in
    -H)  Host="$2"; shift;;
    -C)  Community="$2"; shift;;
    -p)  Process="$2"; shift;;
    -a)  Arguments="$2"; shift;;
    -n)  MemoryCheck="no"; shift;;
    -w)  Warn="$2"; shift;;
    -c)  Critical="$2"; shift;;
    --) shift; break;;
    *)  break;; # terminate while loop
    esac
    shift
done

# Check for not-set variables that we need to have
if [ x${Host} = x ] || [ x${Process} = x ]; then
    echo "usage: $0 -H host
    -C ROCommString
    -p process
    -a arguments
    -n (don't do memory check)
    -w WarnMemoryLevel
    -c CritMemoryLevel
"
    exit 1
fi

# Set Warn and Critical if they're not set
if [ x${Warn} = x ]; then
    Warn="140000"
fi
if [ x${Critical} = x ]; then
    Critical="160000"
fi
if [ x${MemoryCheck} = x ]; then
    MemoryCheck="yes"
fi

PROCPIDS=`snmpwalk -c ${Community} -v 2c "$Host" HOST-RESOURCES-MIB::hrSWRunName | grep "$Process" | sed 's/.*\.\([0-9]*\) = STRING.*/\1/'`

for i in $PROCPIDS ; do
    if snmpwalk -c ${Community} -v 2c "$Host" HOST-RESOURCES-MIB::hrSWRunParameters.$i | egrep "$Arguments" >/dev/null 2>&1 ; then

        # It's there
        PID=${i}
    fi
done

if [ x${PID} = x ]; then
    # it's not there!
    Message="CRITICAL - not running: $Process $Arguments"
    ExitCode=2
else
    # It's there; prep for exit in case no memory check
    Message="OK - pid is $PID"
    ExitCode=0

    if [ "$MemoryCheck" = "yes" ]; then
        # doing memory check
        MemUsage=`ssh $Host ps auxww | grep $PID | grep $Arguments | grep -v grep | awk '{ print $5 }'`
        # Prep for exit in case no Warn/Crit threshold
        Message="OK - Process $PID is using $MemUsage KBytes of memory."
        ExitCode=0

        if [ "$MemUsage" -gt "$Warn" ]; then
            # Warning
            Message="WARNING - Process $PID is using $MemUsage KBytes of memory."
            ExitCode=1
        fi # End of check for Warn threshold
    
        if [ "$MemUsage" -gt "$Critical" ]; then
            # Critical
            Message="CRITICAL - Process $PID is using $MemUsage KBytes of memory."
            ExitCode=2
        fi # End of check for Critical threshold

    fi # End of Memory Check

fi

if [ "x${Message}" = "x" ]; then
    Message="You goofed, you silly sysadmin."
    ExitCode=65535
fi

echo "$Message"
exit $ExitCode
