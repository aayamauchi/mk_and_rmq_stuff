#!/usr/local/bin/bash
#
# $0 user password host state duration

PATH=/bin:/usr/bin:/usr/local/bin

ERRORS=`echo "SELECT IFNULL(sum(value),0) FROM ft_counts WHERE counter_name LIKE
'%feeds_connection_error%'" | mysql -N -u $1 -p$2 -h $3 controller_ftdb`

if [[ "${ERRORS}" != "" ]] && [[ "${ERRORS}" != NULL ]] && [[ ${ERRORS} -gt 0 ]]
then
    echo "Errors detected in XBRS for Feeds API."
    echo "SELECT counter_name, hostname, pid, value FROM ft_counts WHERE counter_name LIKE 
    '%feeds_connection_error%' AND value > 0\G" | mysql -N -u $1 -p$2 -h $3 controller_ftdb
    if [ "$4" != "" ]
    then
        if [[ $5 -gt 600 ]] || [[ $4 -eq 2 ]]
        then
            exit 2
        fi
    fi
    exit 1
elif [ "${ERRORS}" == "" ]
then
    echo "Error querying database."
    exit 3
elif [ "${ERRORS}" == "NULL" ]
then
    echo "No data returned from db"
    exit 3
fi

echo "No errors detected in XBRS for Feeds API"
exit 0
