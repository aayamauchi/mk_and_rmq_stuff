#!/usr/bin/env bash
# SBRS Data 1.0 Monitoring Node Checks
# Eng Owner: Pawan Dube
# MonOps: Valerii Kafedzhy (vkafedzh@cisco.com)
# See MONOPS-1360
#==============================================================================
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

NAGIOS_WARNING=
NAGIOS_CRITICAL=

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to determine SBRS Data Status"
TIME=60
SERVICE="check_ft_status"

USAGE=$( cat << EOM
SBRS DATA 1.0 Node Status Checks.
Usage: `basename ${0}` -h host -p port -t timeout -c critical_value -w warning_value [-v]
           -h  SBRS DATA Node URL
           -p  Port number of instance (default: 12200) JSON
           -t  Timeout for cURL
           -c  Critical threshold
           -w  Warning threshold
           -v  Turn on debugging output
EOM
)

OPTIONS=
while getopts ":h:p:t:c:w:v" OPTIONS
do
    case ${OPTIONS} in
        h ) HOST="${OPTARG}";;
        p ) PORT="${OPTARG}";;
        t ) TIME="${OPTARG}";;
        c ) NAGIOS_CRITICAL="${OPTARG}";;
        w ) NAGIOS_WARNING="${OPTARG}";;
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

if [ ! -z "${NAGIOS_WARNING}" -a ! -z "${NAGIOS_CRITICAL}" ]; then
   if [ ${NAGIOS_CRITICAL} -ge ${NAGIOS_WARNING} ]; then
      echo "`basename ${0}`: error: warning threshold must be grater than critical threshold"
      exit ${EXIT_CODE}
   fi
fi

if [ "x${HOST}x" = "xx" ]; then
      echo "`basename ${0}`: error: you must specify a HOSTNAME for this check"
      exit ${EXIT_CODE}
fi

if [ "x${PORT}x" = "xx" ]; then
	PORT="12200"
fi

check=`curl --connect-timeout ${TIME} --silent http://${HOST}:${PORT}/check_ft_status | tr -d '\"|\}|\{' | sed -e 's/\./\_/' -e 's/^[ \t]*//;s/[ \t]*$//' | tr ',' '\n' | awk -F: '{ print $2 }' | grep -v "ironport" | grep '[0-9]\{5\}' | sed 's/]//g' | sed 's/ //g' | wc -l`

if [ "${check}" -le "${NAGIOS_CRITICAL}" ]; then
	INFO="${SERVICE} has CRITICAL value ${check} on ${HOST} (crit threshold: ${NAGIOS_CRITICAL})"
	EXIT_CODE=${STATE_CRIT}
        elif [ "${check}" -le "${NAGIOS_WARNING}" ]; then
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
