#!/usr/local/bin/bash
#
# $0 user password host

PATH=/bin:/usr/bin:/usr/local/bin

ERRORS=`echo "SELECT sum(value) FROM ft_counts WHERE counter_name LIKE
'$4%'" | mysql -N -u $1 -p$2 -h $3 controller_ftdb`

if [[ "${ERRORS}" != "" ]] && [[ "${ERRORS}" != "NULL" ]] && [[ ${ERRORS} -gt 0 ]]
then
    echo "${ERRORS} errors detected in XBRS.  Counter: $4"
    echo "SELECT counter_name, hostname, pid, value FROM ft_counts WHERE counter_name LIKE '$4%' 
    AND value > 0\G" | mysql -N -u $1 -p$2 -h $3 controller_ftdb 
    exit 1
elif [ "${ERRORS}" == "" ]
then
    echo "Error querying database."
    exit 3
elif [ "${ERRORS}" == "NULL" ]
then
    echo "No data returned from db - We would like to treat this as UNKNOWN,"
    echo "But Dev needs to fix the App."
    exit 0
fi

echo "No errors detected in XBRS for Counter: $4"
exit 0
