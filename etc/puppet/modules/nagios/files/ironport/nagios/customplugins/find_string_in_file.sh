#!/bin/sh
#
# Very simple script to find a string in a file.
#
# Tim Spencer <tspencer@ironport.com>
# Mon Mar  6 19:29:36 PST 2006
#
# find_string_in_file.sh <hostname> <stringtosearchfor> <filetosearch>
#
#  stringtosearchfor could be a regex, I suppose.
#

HOST=$1
STRING=$2
FILE=$3

ssh "$HOST" egrep "$STRING" "$FILE" >/dev/null 2>&1

if [ ! $? -gt 0 ] ; then
	echo "CRITICAL - $STRING found in $FILE"
	exit 2
fi

echo "OK - $FILE has no $STRING"

