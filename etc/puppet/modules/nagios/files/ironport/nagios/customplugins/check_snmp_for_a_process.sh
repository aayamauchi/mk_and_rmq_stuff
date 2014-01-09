#!/bin/sh
#
# Tim Spencer <tspencer@ironport.com>
# Thu Mar  2 21:08:22 PST 2006
#
# $1 is the host, $2 is the process, $3 Are the arguments
#
# you can find out the args for this by doing something like this:
# snmpwalk -c y3ll0w\! -v 2c HOST | grep PID
#  Where HOST is the name of the host that it's running on
#  And PID is the pid of the process (previously gathered with ps)
# Then look at the hrSWRunName for the process, and the
# hrSWRunParameters for the arguments.  Have fun!
#

PATH=/bin:/usr/bin:/usr/local/bin

PROCPIDS=`snmpwalk -c y3ll0w\! -v 2c "$1" HOST-RESOURCES-MIB::hrSWRunName | grep "$2" | sed 's/.*\.\([0-9]*\) = STRING.*/\1/'`

for i in $PROCPIDS ; do
	if snmpwalk -c y3ll0w\! -v 2c "$1" HOST-RESOURCES-MIB::hrSWRunParameters.$i | egrep "$3" >/dev/null 2>&1 ; then
		# It's there
		echo "OK - pid is $i"
		exit 0
	fi
done

# it's not there!
echo "not running: $2 $3"
exit 2

