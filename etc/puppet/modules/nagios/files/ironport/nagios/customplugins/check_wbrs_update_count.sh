#!/usr/local/bin/bash
#==============================================================================
# check_wbrs_update_count.sh
#
# Nagios check for Matterhorn update count. This is a wrapper for
# check_mysql_data.sh that does some additional threshold matching depending
# on the update type: full or incremental.
#
# Return codes and their meaning:
#         0 (ok)
#         1 (warning)
#         2 (critical)
#         3 (unknown)
#
# 2011-09-27 jramache
#==============================================================================
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
CHECK_MYSQL_DATA="/usr/local/ironport/nagios/customplugins/check_mysql_data.py"

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to determine update count"

USAGE=$( cat << EOM
Usage: `basename ${0}` -h db_host -d db_name -u db_user -p db_pass -t update_type -q query [-v]
           -h  Database hostname
           -u  Database user
           -p  Database password
           -d  Database name
           -t  Update type (full or incremental)
           -q  Query to perform
           -v  Turn on debugging output
EOM
)

DB_HOST=
DB_NAME=
DB_USER=
DB_PASS=
U_TYPE=
QUERY=

OPTIONS=
while getopts ":h:d:u:p:t:q:v" OPTIONS
do
    case ${OPTIONS} in
        h ) DB_HOST="${OPTARG}" ;;
        d ) DB_NAME="${OPTARG}" ;;
        u ) DB_USER="${OPTARG}" ;;
        p ) DB_PASS="${OPTARG}" ;;
        t ) U_TYPE="${OPTARG}" ;;
        q ) QUERY="${OPTARG}" ;;
        v ) VERBOSE=1;;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE} ;;
    esac
done

if [ ${VERBOSE} ]; then
    set -x
fi

if [ -z "${DB_HOST}" -o -z "${DB_NAME}" -o -z "${DB_USER}" -o -z "${DB_PASS}" -o -z "${U_TYPE}" -o -z "${QUERY}" ]; then
   echo "${USAGE}"
   exit ${EXIT_CODE}
fi

#------------------------------------------------------------------------
# Run the query
#------------------------------------------------------------------------
RESULT=`${CHECK_MYSQL_DATA} --host ${DB_HOST} --db ${DB_NAME} --user ${DB_USER} --password ${DB_PASS} --query "${QUERY}" --raw`

#------------------------------------------------------------------------
# Check thresholds (if result is a number)
#------------------------------------------------------------------------
if [ ${RESULT} -eq ${RESULT} ] 2>/dev/null; then
    if [ ${RESULT} -eq 1 ]; then
        INFO="${RESULT} update record found"
    else
        INFO="${RESULT} update records found"
    fi
    if [ "${U_TYPE}" = "full" ]; then
        #---------------------
        # FULL UPDATES
        #---------------------
        if   [ ${RESULT} -eq 0 ]; then
            EXIT_CODE=${STATE_CRIT}
        elif [ ${RESULT} -ge 1 -a ${RESULT} -le 2 ]; then
            EXIT_CODE=${STATE_WARN}
        elif [ ${RESULT} -ge 3 -a ${RESULT} -le 6 ]; then
            EXIT_CODE=${STATE_OK}
        elif [ ${RESULT} -gt 6 ]; then
            EXIT_CODE=${STATE_WARN}
        else
            EXIT_CODE=${STATE_CRIT}
        fi
    elif [ "${U_TYPE}" = "incremental" ]; then
        #---------------------
        # INCREMENTAL UPDATES
        #---------------------
        if   [ ${RESULT} -eq 0 ]; then
            EXIT_CODE=${STATE_CRIT}
        elif [ ${RESULT} -ge 1 -a ${RESULT} -le 5 ]; then
            EXIT_CODE=${STATE_WARN}
        else
            EXIT_CODE=${STATE_OK}
        fi
    else
        EXIT_CODE=${STATE_UNKN}
    fi
else
    INFO="Expected a number, but got this instead: ${RESULT}"
fi

#------------------------------------------------------------------------
# Exit
#------------------------------------------------------------------------
case ${EXIT_CODE} in
    ${STATE_OK}   ) echo "OK - ${INFO}" ;;
    ${STATE_WARN} ) echo "WARNING - ${INFO}" ;;
    ${STATE_CRIT} ) echo "CRITICAL - ${INFO}" ;;
    ${STATE_UNKN} ) echo "UNKNOWN - ${INFO}" ;;
    *             ) echo "UNKNOWN - ${INFO}" ;;
esac

exit ${EXIT_CODE}