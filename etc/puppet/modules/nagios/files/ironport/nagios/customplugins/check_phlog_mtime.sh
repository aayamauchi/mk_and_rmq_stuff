#!/bin/sh -

PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin"
exit_message="OK"
exit_status="0"

######################################################################
# subs
######################################################################

usage()
{
	echo "USAGE: `basename $0` -h hostname -f filename -w warningsecs -c criticalsecs"
	exit 0
}

print_status()
{
	[ "$1" ] && exit_message="$1"
	[ "$2" ] && exit_status="$2"
	echo "$exit_message"
	exit $exit_status
}

######################################################################
# main
######################################################################

# must have "-d <domain>"
[ $# -ge 4 ] || usage

# process command line args
while getopts h:f:w:c:a arg
do
    case "$arg" in
     h) hostname="$OPTARG";;
     f) filename="$OPTARG";;
     w) warning="$OPTARG";;
     c) critical="$OPTARG";;
     *) usage;;
    esac
done

today=`date -u +%Y-%m-%d`
filename=/data/wbrsphonehomelogs/phlog-${today}

file=`ssh nagios@${hostname} "stat -f %m $filename"`

test=`echo "0$file * 1" | bc`

if [ "$test" != "$file" ]
then
    exit_message="UNKNOWN - $filename does not exist?"
    exit_status="3"
    print_status
fi

date=`date +%s`

age=`echo $date - $file | bc`

if [ "${age}" -ge "${critical}" ]
then
	exit_message="CRITICAL - $filename age $age > $critical seconds"
	exit_status="2"
elif [ "${age}" -ge "${warning}" ]
then
	exit_message="WARNING - $filename age $age > $warning seconds"
	exit_status="1"
else
	exit_message="OK - $filename $age seconds old"
	exit_status="0"
fi

print_status

