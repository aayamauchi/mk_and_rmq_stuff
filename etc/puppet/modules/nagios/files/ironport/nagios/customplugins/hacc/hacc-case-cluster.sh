#!/usr/local/bin/bash
# HACC Case Cluster monitoring Script
# MONOPS: Valerii Kafedzhy <vkafedzh@cisco.com>
# See MONOPS-1411
# Eng Owner: Pawan Dube <pdube@cisco.com>
#==============================================================================
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

NAGIOS_WARNING=
NAGIOS_CRITICAL=

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to determine HACC Case Cluster Status"
TIME=300

USAGE=$( cat << EOM
HACC Case Cluster Status Checker
Usage: `basename ${0}` -h host [-p port] [-t timeout] [-s service] -c value -w value [-v]
           -h  HACC Case Cluster hostname
           -p  Port number os instance (default: 10180) TXT
           -t  Timeout for cURL (optional)
	   -s  Service Name (optional)
           -c  Critical threshold
           -w  Warning threshold
           -v  Turn on debugging output
EOM
)

OPTIONS=
while getopts ":h:p:t:c:w:s:v" OPTIONS
do
    case ${OPTIONS} in
        h ) HOST="${OPTARG}";;
        p ) PORT="${OPTARG}";;
        t ) TIME="${OPTARG}";;
        c ) NAGIOS_CRITICAL="${OPTARG}";;
        w ) NAGIOS_WARNING="${OPTARG}";;
        v ) VERBOSE=1;;
	s ) SERVICE="${OPTARG}";;
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

if [ ${NAGIOS_CRITICAL} -le ${NAGIOS_WARNING} ]; then
      echo "`basename ${0}`: error: critical threshold must be grater than warning threshold"
      exit ${EXIT_CODE}
fi

if [ "x${HOST}x" = "xx" ]; then
      echo "`basename ${0}`: error: you must specify a HOSTNAME for this check"
      exit ${EXIT_CODE}
fi

if [ "x${PORT}x" = "xx" ]; then
	PORT="10180"
fi

if [ "x${SERVICE}x" = "xx" ]; then
	SERVICE="Engine HUPd"
fi

check=`curl --connect-timeout ${TIME} --silent http://${HOST}:${PORT}/engine-status | grep "${SERVICE}" | awk '{print $(NF-2)}' | sed -e 's/^[^0-9]*//'`

if [ "x${check}x" = "xx" ]; then
      echo "`basename ${0}`: Couldn't fetch ${HOST}"
      exit ${EXIT_CODE}
fi

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
