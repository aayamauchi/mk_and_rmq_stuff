#!/usr/bin/env bash
# See MONOPS-1359
# 3/18/2013 Valerii Kafedzhy (vkafedzh@cisco.com)
#==============================================================================
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

NAGIOS_WARNING=
NAGIOS_CRITICAL=

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to determine SBNP Rep data"
TIME=60

USAGE=$( cat << EOM
SBNP Rep Data checks.
Usage: `basename ${0}` -h host -p port -t timeout -s service -c value -w value [-v]
           -h  SBNP Red Data hostname
           -p  Port number os instance (default: 11080) JSON
           -t  Timeout for cURL
	   -s  Service Name (ex.queue_items_behind)
           -c  Critical threshold
           -w  Warning threshold
           -v  Turn on debugging output
	   -i  Reputation Data (by default /counters)
EOM
)

OPTIONS=
while getopts ":h:p:t:c:w:s:v:i" OPTIONS
do
    case ${OPTIONS} in
        h ) HOST="${OPTARG}";;
        p ) PORT="${OPTARG}";;
        t ) TIME="${OPTARG}";;
        c ) NAGIOS_CRITICAL="${OPTARG}";;
        w ) NAGIOS_WARNING="${OPTARG}";;
        v ) VERBOSE=1;;
	s ) SERVICE="${OPTARG}";;
	i ) REP=1;;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE};;
    esac
done

if [ ${VERBOSE} ]; then
    set -x
fi

if [ ${REP} ]; then
    PAGE="reputation_data_info"
else
    PAGE="counters"
fi


if [ -z "${NAGIOS_WARNING}" -o -z "${NAGIOS_CRITICAL}" ]; then
   echo "${USAGE}"
   exit ${EXIT_CODE}
fi

if [ ! -z "${NAGIOS_WARNING}" -a ! -z "${NAGIOS_CRITICAL}" ]; then
   if [ `echo "${NAGIOS_CRITICAL} <= ${NAGIOS_WARNING}" | bc 2>/dev/null` -eq 1 ]; then
      echo "`basename ${0}`: error: critical threshold must be greater than warning threshold"
      exit ${EXIT_CODE}
   fi
fi

if [ "x${HOST}x" = "xx" ]; then
      echo "`basename ${0}`: error: you must specify a HOSTNAME for this check"
      exit ${EXIT_CODE}
fi

if [ "x${PORT}x" = "xx" ]; then
	PORT="11080"
fi

if [ "x${SERVICE}x" = "xx" ]; then
      echo "`basename ${0}`: error: you must specify a SERVICE name for this check"
      exit ${EXIT_CODE}

fi

check=`curl --connect-timeout ${TIME} --silent http://${HOST}:${PORT}/${PAGE} | tr -d '\"|\}|\{' | sed -e 's/\./\_/' -e 's/^[ \t]*//;s/[ \t]*$//' | tr ',' '\n' | grep ${SERVICE} | awk -F: '{ print $2 }' | sed 's/ //g'`

if [ "${check}" -ge "${NAGIOS_CRITICAL}" ]; then
	INFO="${SERVICE} has CRITICAL value ${check} on ${HOST} (crit threshold: ${NAGIOS_CRITICAL})"
	EXIT_CODE=${STATE_CRIT}
        elif [ "${check}" -ge "${NAGIOS_WARNING}" ]; then
            INFO="${SERVICE} has WARNING value ${check} on ${HOST}(warn threshold: ${NAGIOS_WARNING})"
            EXIT_CODE=${STATE_WARN}
        else
            INFO="${SERVICE} is OK with ${check} value. (warn threshold: ${NAGIOS_WARNING})"
            EXIT_CODE=${STATE_OK}
fi

case ${EXIT_CODE} in
    ${STATE_OK}   ) echo "OK - ${INFO}";;
    ${STATE_WARN} ) echo "WARNING - ${INFO}";;
    ${STATE_CRIT} ) echo "CRITICAL - ${INFO}";;
    ${STATE_UNKN} ) echo "UNKNOWN - ${INFO}";;
    *             ) echo "UNKNOWN - ${INFO}";;
esac

exit ${EXIT_CODE}
