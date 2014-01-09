#!/bin/sh

# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_snmp_ip_orig.sh#1 $

# step through and get values for command line arguments
# echo usage if incorrect argument found
while [ $# -gt 0 ]; do
    case "$1" in
    -H)  hostname="$2"; shift;;
    -i)  IP="$2"; shift;;
    -c)  community="$2"; shift;;
    --)	shift; break;;
    -*)
        echo >&2 \
        "usage: $0 -H hostname -c community -i IP"
        exit 1;;
    *)  break;;	# terminate while loop
    esac
    shift
done

# Exit if user did not define hostname, mountpoint, or community
if [ x${hostname} = x ] || [ x${community} = x ] || [ x${IP} = x ]; then
    echo "usage: $0 -H hostname -c community -i IP"
    exit 1
fi

snmpwalk -v 1 -Os -c ${community} ${hostname} .1.3.6.1.2.1.4.20.1.2 | grep ${IP} >> /dev/null 2>&1

status=`echo $?`

if [ "$status" -eq 0 ]
then
	echo "OK - VIP IP ${IP} is listening on ${hostname}"
	exit 0 # a-ok
else
	echo "CRITICAL - VIP IP ${IP} is not listening on ${hostname}"
	exit 2 # bad news!
fi

# If we haven't already exited, something is seriously wrong.
exit 3

