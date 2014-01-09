#!/usr/bin/env bash
# MONOPS-1157 get counter value from ftdb
#==============================================================================
# ftdb_counter.sh
#
# Request counter value from FT database
#
# Return codes and their meaning:
#         0 (ok)
#         1 (warning)
#         2 (critical)
#         3 (unknown)
#
# Output:
#     Cacti:
#         counter_name:N  (where N is the value of requested counter)
#
# 2013-02-01 mtiurin
#==============================================================================

PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
VERBOSE=0

usage() {
    cat <<EOF
This script request counter value from ftdb for specified host

Ticket MONOPS-1157

USAGE:
    $(basename $0) -H <HOSTNAME> -c <FT_COUNTER> [-p <OUTPUT_COUNTER>] -d <DATABASE_HOST> [-b <DATABASE_NAME>] -u <DATABASE_USERNAME> -p <DATABASE_PASSWORD> [-v] [-h]

Options
    -H      requested cluster member hostname or IP address
    -c      requested counter name
    -n      counter name in output (dafault value of -c)
    -d      database host where ftdb is located
    -b      ftdb database name (default "ftdb")
    -u      MySQL user name
    -p      MySQL user password
    -v      turn on verbose mode (default off)
    -h      show this help screen and exit

Example:
    $(basename $0) -H blade-03-c-02.vega.ironport.com -c ham_manager:status_counters:ham_queue_size:st -n ham_queue_size -d prod-fozzie-db-s1.vega.ironport.com -u reader -p READER_PASSWORD

EOF
}

check_hostname() {
    # check that value is valid hostname or IP address
    echo "$1" | grep -Eq '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}$'
    if [ $? -ne 0 ] ; then
	# not IP address - try to resolve
	host "$1" > /dev/null 2>&1 || {
	    echo "Bad hostname $1"
	    exit $STATE_CRIT
	}
    fi
}

if [ -z "$1" ] ; then
    usage
    exit $STATE_UNKN
fi

# parse CLI options using bash getopts
while getopts ":H:c:n:d:b:u:p:vh" opt; do
    case "$opt" in
	H ) HOSTNAME="$OPTARG"
	    check_hostname $HOSTNAME
	    ;;
	c ) FT_COUNTER="$OPTARG"
	    ;;
	n ) OUTPUT_COUNTER=$(echo "$OPTARG" | sed 's/:/-/g')
	    ;;
	d ) DATABASE_HOST="$OPTARG"
	    check_hostname $DATABASE_HOST
	    ;;
	b ) DATABASE_NAME="$OPTARG"
	    ;;
	u ) DATABASE_USERNAME="$OPTARG"
	    ;;
	p ) DATABASE_PASSWORD="$OPTARG"
	    ;;
	v ) VERBOSE=1
	    ;;
	h ) usage
	    exit $STATE_UNKN
	    ;;
	* ) usage
	    exit $STATE_UNKN
	    ;;
    esac
done

# check required options values
for reqopt in HOSTNAME FT_COUNTER DATABASE_HOST DATABASE_USERNAME DATABASE_PASSWORD ; do
    if [ -z ${!reqopt} ] ; then
	echo -e "$reqopt must be specified\n"
	usage
	exit $STATE_UNKN
    fi
done
# check optional options values
[ -z $OUTPUT_COUNTER ] && OUTPUT_COUNTER=$(echo $FT_COUNTER | sed 's/:/-/g')
[ -z $DATABASE_NAME ] && DATABASE_NAME=ftdb

######### main
MYSQLCOMMAND="mysql -N -h$DATABASE_HOST -u$DATABASE_USERNAME -p$DATABASE_PASSWORD $DATABASE_NAME"
MYSQLQUEUE="SELECT value FROM ft_counts WHERE hostname='${HOSTNAME}' AND counter_name like '%${FT_COUNTER}';"

[ $VERBOSE -ne 0 ] && echo -e "Execute command:\n$MYSQLCOMMAND -e \"$MYSQLQUEUE\""
OUTPUT=$($MYSQLCOMMAND -e "$MYSQLQUEUE")

if [ $? -ne 0 ] ; then
    [ $VERBOSE -ne 0 ] && echo "Got error when execute queue"
    exit $STATE_UNKN
fi

echo "${OUTPUT_COUNTER}:$OUTPUT"

exit $STATE_OK
