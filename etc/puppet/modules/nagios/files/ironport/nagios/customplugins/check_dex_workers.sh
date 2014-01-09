#!/bin/sh
#
# Check out http://eng.ironport.com/docs/is/fpr/1_3/eng/fpr_backend.rst
# for what this does.  Basically, it grabs the number contained in the
# URL and checks to see if it's smaller than the argument supplied.
# That means that it was recently restarted, which is bad... (!)
#
# Tim Spencer <tspencer@ironport.com>
# Thu Jun 29 15:40:19 PDT 2006
#
# find_string_in_file.sh <hostname> <uptime>
#   Where uptime is the age under which we need to go critical.  
#
# PORT could be an argument
#

HOST=$1
UPTIME=$2
PORT=10080

AGE=`wget -q -O - http://$HOST:$PORT/status?age`

if [ "$AGE" -lt "$UPTIME" ] ; then
	echo "CRITICAL - age $AGE is less than $UPTIME... Check to see why it restarted"
	exit 2
fi

echo "OK - age $AGE is more than $UPTIME"

