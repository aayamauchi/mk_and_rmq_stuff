#!/bin/sh

PATH=/bin:/usr/bin:/usr/local/bin

# step through and get values for command line arguments
# echo usage if incorrect argument found
while [ $# -gt 0 ]; do
    case "$1" in
    -H)  hostname="$2"; shift;;
    -m)  mountpoint="$2"; shift;;
    -c)  community="$2"; shift;;
    --)	shift; break;;
    -*)
        echo >&2 \
        "usage: $0 -H hostname -c community -m mountpoint"
        exit 1;;
    *)  break;;	# terminate while loop
    esac
    shift
done

# Exit if user did not define hostname, mountpoint, or community
if [ x${hostname} = x ] || [ x${community} = x ] || [ x${mountpoint} = x ]; then
    echo "usage: $0 -H hostname -c community -m mountpoint"
    exit 1
fi

# Strip trailing slashes!
mountpoint=`dirname ${mountpoint}/x`

#MountPoint=`snmpwalk -v 2c -Ov -c 'y3ll0w!' dc3110.dc1.postx.com .1.3.6.1.2.1.25.3.8.1.3 | grep postxeo | cut -d" " -f 2 | sed 's/"//g'`
WALKOUT=`snmpwalk -v 2c -Ov -c ${community} ${hostname} .1.3.6.1.2.1.25.3.8.1.3 2>&1`
walkstatus=$?
echo ${WALKOUT} | grep ${mountpoint} >> /dev/null 2>&1
status=$?

if [ "$status" -eq 0 ]
then
	echo "OK - Mountpoint ${mountpoint} is mounted on ${hostname}"
	exit 0 # a-ok
elif [ "$walkstatus" -ne 0 ]
then
        echo "UNKNOWN - Mountpoint ${mountpoint} data not collected from ${hostname}"
        echo "snmpwalk exit code: ${walkstatus}"
        printf "%b" "$WALKOUT"
        echo 
        exit 3
else
	echo "CRITICAL - Mountpoint ${mountpoint} is not mounted on ${hostname}"
	exit 2 # bad news!
fi

# If we haven't already exited, something is seriously wrong.
exit 3

