#!/usr/local/bin/bash
#
# $0 user password host

PATH=/bin:/usr/bin:/usr/local/bin

ERRORS=`echo "SELECT count(value) FROM ft_counts WHERE counter_name LIKE
'controller.finder:errors%'" | mysql -N -u $1 -p$2 -h $3 controller_ftdb`

if [[ "${ERRORS}" != "" ]] && [[ "${ERRORS}" != "NULL" ]] && [[ ${ERRORS} -gt 0 ]]
then
    echo "${ERRORS} rules in XBRS, not in Feeds"
    echo "SELECT counter_name FROM ft_counts WHERE counter_name LIKE 'controller.finder:errors%'" |\
        mysql -N -u $1 -p$2 -h $3 controller_ftdb | awk -F: '{ print $3 }'
    exit 2
elif [ "${ERRORS}" == "" ]
then
    echo "Error querying database."
    exit 3
elif [ "${ERRORS}" == "NULL" ]
then
    echo "No data returned from db."
    exit 3
fi

echo "No missing feeds rules detected by XBRS."
exit 0
