#!/bin/sh
#
# Finds a String in a file, and checks if there are more than Number
# instances of String.
#
# Modified from an original script by Tim Spencer <tspencer@ironport.com>
#
# find_string_count_in_file.sh -H hostname -f file -s string -n number
#
#  stringtosearchfor could be a regex, I suppose.
#

Condition=OK
ExitCode=0

# step through and get values for command line arguments
# echo usage if incorrect argument found
while [ $# -gt 0 ]; do
    case "$1" in
    -H)  Host="$2"; shift;;
    -f)  File="$2"; shift;;
    -s)  String="$2"; shift;;
    -n)  Number="$2"; shift;;
    --) shift; break;;
    *)  break;; # terminate while loop
    esac
    shift
done

# Exit if user did not set the hostname
if [ x${Host} = x ]; then
    echo "You must specify a host to search on!"
    echo "usage: $0 -H hostname -f file -s string [-n number]"
    exit 1
fi

# Exit if user did not set the filename
if [ x${File} = x ]; then
    echo "You must specify a file to search!"
    echo "usage: $0 -H hostname -f file -s string [-n number]"
    exit 1
fi

# Exit if user did not set the String value
if [ x${String} = x ]; then
    echo "You must specify a string to search for!"
    echo "usage: $0 -H hostname -f file -s string [-n number]"
    exit 1
fi

Count=`ssh "$Host" egrep "$String" "$File" | wc -l | awk '{ print $1 }'`

if [ $Count -gt ${Number:=0} ] ; then
    Condition=CRITICAL
    ExitCode=2
fi

echo "$Condition - string $String found in $File $Count times- threshold is $Number."
exit $ExitCode

