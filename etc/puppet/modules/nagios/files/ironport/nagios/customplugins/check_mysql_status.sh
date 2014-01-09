#!/usr/local/bin/bash
#==============================================================================
# check_mysql_status.sh
#
# Retrieve a mysql variable status value using "SHOW GLOBAL STATUS" and
# compare against thresholds. Initially created to create a mysql uptime
# monitor.
#
# Note: Assumes values involved are integers. This script could be beefed up
# to deal with floats if it is needed later on.
#
# 2012-07-20 jramache
#==============================================================================
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to obtain mysql status"

NAGIOS_WARNING=
NAGIOS_CRITICAL=
INVERSE=0
DB_HOST=""
DB_USER=""
DB_PASS=""
MYSQL_VARIABLE=""
VERBOSE=

USAGE=$( cat << EOM
Usage: `basename ${0}` -h db_host -u db_user -p db_pass -m mysql_variable -c crit_threshold -w warn_threshold [-i] [-v]
           -h  Database hostname
           -u  Database user
           -p  Database password
           -m  Mysql status variable to query for
           -c  Critical threshold
           -w  Warning threshold
           -i  Inverse (value must be >= thresholds provided, otherwise it must be <=)
           -v  Turn on debugging output
EOM
)

OPTIONS=
while getopts ":h:u:p:m:c:w::iv" OPTIONS
do
    case ${OPTIONS} in
        h ) DB_HOST="${OPTARG}";;
        u ) DB_USER="${OPTARG}";;
        p ) DB_PASS="${OPTARG}";;
        m ) MYSQL_VARIABLE="${OPTARG}";;
        c ) NAGIOS_CRITICAL="${OPTARG}";;
        w ) NAGIOS_WARNING="${OPTARG}";;
        i ) INVERSE=1;;
        v ) VERBOSE=1;;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE};;
    esac
done

if [ ${VERBOSE} ]; then
    set -x
fi

if [ -z "${NAGIOS_WARNING}" -o -z "${NAGIOS_CRITICAL}" ]; then
   echo "${USAGE}"
   exit ${EXIT_CODE}
fi

if [ ${INVERSE} -ne 1 ]; then
    if [ `echo "${NAGIOS_CRITICAL} <= ${NAGIOS_WARNING}" | bc 2>/dev/null` -eq 1 ]; then
       echo "`basename ${0}`: error: critical threshold must be greater than warning threshold"
       exit ${EXIT_CODE}
    fi
else
    if [ `echo "${NAGIOS_CRITICAL} >= ${NAGIOS_WARNING}" | bc 2>/dev/null` -eq 1 ]; then
       echo "`basename ${0}`: error: critical threshold must be less than warning threshold (inverse is on)"
       exit ${EXIT_CODE}
    fi
fi
NAGIOS_CRITICAL=`echo ${NAGIOS_CRITICAL} | bc`
NAGIOS_WARNING=`echo ${NAGIOS_WARNING} | bc`

if [ "x${MYSQL_VARIABLE}x" = "xx" ]; then
      echo "`basename ${0}`: error: you must supply a mysql variable to retrieve"
      exit ${EXIT_CODE}
fi

if [ "${DB_HOST}" = "" -o "${DB_USER}" = "" -o "${DB_PASS}" = "" -o "${MYSQL_VARIABLE}" = "" ]; then
    echo "${USAGE}"
    exit ${EXIT_CODE}
fi

# Retrieve status
STATUS=`mysql --silent -N --host=${DB_HOST} --user="${DB_USER}" --password="${DB_PASS}" --execute="SHOW GLOBAL STATUS LIKE '${MYSQL_VARIABLE}'"`
if [ ${?} -ne 0 ]; then
    echo "CRITICAL - `echo \"${STATUS}\" | tr '\n' ' '`"
    exit 2
fi
if [ "${STATUS}" == "" ]; then
    echo "CRITICAL - Empty result from mysql"
    exit 2
fi
ROW_COUNT=`echo "${STATUS}" | wc -l | bc`
if [ ${ROW_COUNT} -ne 1 ]; then
    echo "CRITICAL - Expected one row, but got back ${ROW_COUNT}"
    exit 2
fi

# Obtain value
STR_VALUE=`echo "${STATUS}" | awk '{print $NF}'`
NUM_VALUE=`echo "${STATUS}" | awk '{print $NF}' | bc`
if [ "${STR_VALUE}" != "${NUM_VALUE}" ]; then
    echo "CRITICAL - Status returned is NaN: ${STR_VALUE}"
    exit 2
fi

# Compare against thresholds
if [ ${INVERSE} -eq 1 ]; then
    if [ ${NUM_VALUE} -le ${NAGIOS_CRITICAL} ]; then
        INFO="${MYSQL_VARIABLE} is ${NUM_VALUE} (le ${NAGIOS_CRITICAL})"
        EXIT_CODE=${STATE_CRIT}
    elif [ ${NUM_VALUE} -le ${NAGIOS_WARNING} ]; then
        INFO="${MYSQL_VARIABLE} is ${NUM_VALUE} (le ${NAGIOS_WARNING})"
        EXIT_CODE=${STATE_WARN}
    else    
        INFO="${MYSQL_VARIABLE} is ${NUM_VALUE} [gt warning (${NAGIOS_WARNING})]"
        EXIT_CODE=${STATE_OK}
    fi
else
    if [ ${NUM_VALUE} -ge ${NAGIOS_CRITICAL} ]; then
        INFO="${MYSQL_VARIABLE} is ${NUM_VALUE} (ge ${NAGIOS_CRITICAL})"
        EXIT_CODE=${STATE_CRIT}
    elif [ ${NUM_VALUE} -ge ${NAGIOS_WARNING} ]; then
        INFO="${MYSQL_VARIABLE} is ${NUM_VALUE} (ge ${NAGIOS_WARNING})"
        EXIT_CODE=${STATE_WARN}
    else    
        INFO="${MYSQL_VARIABLE} is ${NUM_VALUE} [lt warning (${NAGIOS_WARNING})]"
        EXIT_CODE=${STATE_OK}
    fi
fi

case ${EXIT_CODE} in
    ${STATE_OK}   ) echo "OK - ${INFO}";;
    ${STATE_WARN} ) echo "WARNING - ${INFO}";;
    ${STATE_CRIT} ) echo "CRITICAL - ${INFO}";;
    ${STATE_UNKN} ) echo "UNKNOWN - ${INFO}";;
    *             ) echo "UNKNOWN - ${INFO}";;
esac

exit ${EXIT_CODE}