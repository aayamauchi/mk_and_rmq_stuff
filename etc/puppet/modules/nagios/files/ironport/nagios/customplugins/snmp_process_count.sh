#!/usr/local/bin/bash
#
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/snmp_process_count.sh#1 $ -- check process count for Nagios
#
# dannhowa@cisco.com

PATH=/bin:/usr/bin:/usr/local/bin

# snmpget -t 10 -v2c -c 'y3ll0w!' ops-dev.sfo.ironport.com 1.3.6.1.2.1.25.1.6.0

SNMPGET=snmpget
SNMPOPT="-t 10 -v2c"
SNMPOID="1.3.6.1.2.1.25.1.6.0"

AWK=awk

function usage {
    echo "Usage: $0 -H <host> -C <community string> -w <warn threshold> -c <critical threshold>"
}

# http://dannyman.toldme.com/2005/06/22/sh-bash-getopts/
while getopts H:C:w:c: o
do case "$o" in
    H)  host="$OPTARG";;
    C)  community="$OPTARG";;
    w)  warn="$OPTARG";;
    c)  crit="$OPTARG";;
    *)  usage && exit 3;;
esac
done

if [ ! -n "$host" -o ! -n "$community" -o ! -n "$warn" -o ! -n "$crit" ]; then
    echo "Missing arguments"
    usage && exit 3
fi

# Reset $@
shift `echo $OPTIND-1 | bc`

procs=`$SNMPGET $SNMPOPT -c $community $host $SNMPOID 2>/dev/null | $AWK '{print $4}'`

if [ ! -n "$procs" ]; then
    echo "UNKNOWN: $SNMPGET did not return a value"
    exit 3
elif [ $procs -gt $crit ]; then
    echo "CRITICAL: $procs procs greater than $crit"
    exit 2
elif [ $procs -gt $warn ]; then
    echo "WARNING: $procs procs greater than $warn"
    exit 1
else
    echo "OKAY: $procs procs"
    exit 0
fi
