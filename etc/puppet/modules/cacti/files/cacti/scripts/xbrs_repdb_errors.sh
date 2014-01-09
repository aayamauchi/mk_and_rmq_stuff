#!/usr/local/bin/bash
#==============================================================================
# xbrs_repdb_errors.sh
#
# Obtains daily error count from XBRS Reputation DBs.
#
# 2012-05-11 jramache
#==============================================================================
PRINT=""
PATH=/bin:/usr/bin:/usr/local/bin

DBHOST="${1}"
DBUSER="cactiuser"
DBPASS="cact1pa55"
DB="reputation"

OUTPUTFIELD="errors"

if [ "${DBHOST}" == "" ]; then
    echo "error: hostname argument required"
    exit 1
fi
if [ "`dig ${DBHOST} +short`" = "" ]; then
    echo "error: dns lookup failed for ${DBHOST}"
    exit 1
fi

SQL="select left(from_unixtime(ctime), 10) day, sum(if(errors is null, 0, 1)) errors from statslog group by day order by ctime desc limit 1;"
OUT=`mysql --silent --batch --host="${DBHOST}" --user="${DBUSER}" --password="${DBPASS}" --execute="${SQL}" "${DB}"`
DATE=`echo "${OUT}" | awk '{print $1}'`
ERRORS=`echo "${OUT}" | awk '{print $2}'`

if [ "${DATE}" == "" -o "${ERRORS}" == "" ]; then
    echo "error: invalid query output"
    exit 1
fi

if [ "${DATE}" != `date +"%Y-%m-%d"` ]; then
    echo "error: missing error count for today (latest found was ${DATE})"
    exit 1
fi

echo "${OUTPUTFIELD}:${ERRORS}"

exit 0
