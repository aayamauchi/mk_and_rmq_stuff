#!/usr/local/bin/bash
#==============================================================================
# check_cert_report.sh
#
# Monitor the certificate auditing report and return an aggregate summary
# of certificate expirations.
#
# You must run this as the nagios user. Pass -h for help output.
#
# 2012-06-28 jramache
#==============================================================================
HOST=""
STATUS_FILE=""
AUDIT_FREQUENCY=
VERBOSE=
EXIT_CODE=3

# For informational purposes
CERT_REPORT_URL="https://asdb.ironport.com/portal/certificates"

# Must run as nagios user
if [ "`whoami`" != "nagios" ]; then
    echo "CRITICAL - You must run this script as the nagios user"
    exit 2
fi

USAGE=$( cat <<EOM
Usage: `basename ${0}` -H host -f path -a age [-h] [-v]
           -H  Remote host with certificate report status file
           -f  Path to certificate report status file on remote host
           -a  Maximum age (in seconds) of certificate report status file
           -h  Help
           -v  Turn on debugging output
EOM
)

OPTIONS=
while getopts ":H:f:a::h:v" OPTIONS
do
    case ${OPTIONS} in
        H ) HOST="${OPTARG}";;
        f ) STATUS_FILE="${OPTARG}";;
        a ) AUDIT_FREQUENCY="${OPTARG}";;
        v ) VERBOSE=1;;
        h ) echo "${USAGE}"
            exit 0;;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE};;
    esac
done

if [ ${VERBOSE} ]; then
    set -x
fi

if [ "${HOST}" == "" -o "${STATUS_FILE}" == "" -o "${AUDIT_FREQUENCY}" == "" ]; then
    echo "${USAGE}"
    exit ${EXIT_CODE}
fi

AUDIT_FREQUENCY=`echo "${AUDIT_FREQUENCY}" | bc 2>/dev/null`
T_NOW=`date +%s`

CMD="cat ${STATUS_FILE} 2>&1"
CERT_STATUS=`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOST} "${CMD}" 2>&1`

if [ "${CERT_STATUS}" == "" ]; then
    echo "CRITICAL - Unable to retrieve certificate status file ${STATUS_FILE}"
    exit 2
fi

MTIME=`echo "${CERT_STATUS}" | grep '^mtime: ' | awk '{print $2}' | bc 2>/dev/null`
EXIT_CODE=`echo "${CERT_STATUS}" | grep '^exit: ' | awk '{print $2}' | bc 2>/dev/null`
INFO=`echo "${CERT_STATUS}" | egrep -v '^(exit:|mtime:) '`

if [ -z ${MTIME} -o -z ${EXIT_CODE} ]; then
    echo "CRITICAL - No usable data retrieved from ${STATUS_FILE}"
    exit 2
fi

# BSD and Linux isms
if `uname -s | grep Linux 1>/dev/null 2>/dev/null`; then
   UTIME_TO_STR_CMD='date --date=@'
else
   UTIME_TO_STR_CMD='date -jf%s '
fi


if [ ${MTIME} -eq ${MTIME} ] 2>/dev/null; then
    T_AGE=$(( ${T_NOW} - ${MTIME} ))
    if [ ${T_AGE} -gt ${AUDIT_FREQUENCY} ]; then
        echo "CRITICAL - Stale certificate report data: ${T_AGE} seconds old (threshold is ${AUDIT_FREQUENCY})"
        exit 2
    fi
    if [ ${EXIT_CODE} -eq ${EXIT_CODE} ] 2>/dev/null; then
        if [ ${EXIT_CODE} -eq 0 -o ${EXIT_CODE} -eq 1 -o ${EXIT_CODE} -eq 2 -o ${EXIT_CODE} -eq 3 ]; then
            echo "${INFO}"
            echo
            echo "Based on certificate report dated `${UTIME_TO_STR_CMD}${MTIME}`"
            echo "${CERT_REPORT_URL}"
            exit ${EXIT_CODE}
        else
            echo "CRITICAL - Invalid exit code in certificate report: ${EXIT_CODE}"
            exit 2
        fi
    else
        echo "CRITICAL - Invalid certificate status file: exit code is non-numeric"
        exit 2
    fi
else
    echo "CRITICAL - Invalid certificate status file: bad mtime entry"
    exit 2
fi

exit 0
