#!/bin/sh -

PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin"
exit_message="OK"
exit_status="0"
syslog_server="syslog1.soma.ironport.com" # default
dashes="no"

######################################################################
# subs
######################################################################

usage()
{
cat << EOF 
USAGE: `basename $0` -s syslog_server -h hostname -f filename -w warningsecs -c criticalsecs [-d y]
Note: if you enable "dashes" option (-d y) this script trying to find %Y-%m-%d files instead of +%Y%m%d.

Examples:"
    ./check_syslog_mtime.sh -h prod-corpus-app1.sv4.ironport.com -s prod-ops-syslog1.sv4.ironport.com -f ironport/preprocessor- -w 150 -c 300
    Looking preprocessor-20131129.log on  prod-ops-syslog1.sv4.ironport.com

    ./check_syslog_mtime.sh -h prod-corpus-app1.sv4.ironport.com -s prod-ops-syslog1.sv4.ironport.com -f ironport/preprocessor- -d y -w 150 -c 300
    Looking for preprocessor-2013-11-29.log on  prod-ops-syslog1.sv4.ironport.com

EOF
exit 0
}

print_status()
{
	[ "$1" ] && exit_message="$1"
	[ "$2" ] && exit_status="$2"
        exit_message="${exit_message}
syslog server: ${syslog_server}"
	echo "$exit_message"
	exit $exit_status
}

######################################################################
# main
######################################################################

# must have "-d <domain>"
[ $# -ge 4 ] || usage

# process command line args
while getopts s:h:f:d:w:c:a arg
do
    case "$arg" in
     s) syslog_server="$OPTARG";;
     h) hostname="$OPTARG";;
     f) filename="$OPTARG";;
     d) dashes="$OPTARG";;
     w) warning="$OPTARG";;
     c) critical="$OPTARG";;
     *) usage;;
    esac
done
if [ "$dashes" == "y" -o  "$dashes" == "Y" ]; then
    today="`date +%Y\-%m\-%d`"
else
    today="`date +%Y%m%d`"
fi
filename=/logs/servers/${hostname}/${filename}${today}.log
file=`ssh nagios@${syslog_server} "ls -l  --time-style=+%s  $filename  2>/dev/null"`

if [ "$file" == "" ]
then
    exit_message="UNKNOWN - $filename does not exist?"
    exit_status="3"
    print_status
fi

date=`date +%s`

age=`echo $date - $(echo "$file" | awk '{print $6}') | bc`

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

