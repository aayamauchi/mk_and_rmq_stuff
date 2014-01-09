#!/usr/local/bin/bash
#==============================================================================
# check_zk.sh
#
# Check zookeeper using 4-letter primitives.
#
# 2012-09-25 jramache
#==============================================================================
TIMEOUT=30
TIMEOUT_CMD="/usr/local/ironport/nagios/customplugins/timeout.pl -9 ${TIMEOUT}"

HOST=""
COMMAND=""
STRING=""
PORT=2181
EXACT=0

USAGE=$( cat << EOM
Usage: `basename ${0}` -H hostname [-p port] -c command [-s matchstring] [-e]
           -H  Zookeeper host
           -p  Port to query, ${PORT} by default
           -c  4-letter command
           -s  String expected in response
           -e  Response must exactly match string provided
EOM
)

OPTIONS=
while getopts ":H:p:c:s:e" OPTIONS
do
    case ${OPTIONS} in
        H ) HOST="${OPTARG}";;
        p ) PORT="${OPTARG}";;
        c ) COMMAND="${OPTARG}";;
        s ) STRING="${OPTARG}";;
        e ) EXACT=1;;
        * ) echo "${USAGE}"
            exit 3;;
    esac
done

if [ "${HOST}" = "" ]; then
    echo "UNKNOWN - Host not provided"
    exit 3
fi
if [ "${COMMAND}" = "" ]; then
    echo "UNKNOWN - Command not provided"
    exit 3
fi

CMD="echo '${COMMAND}' | nc ${HOST} ${PORT} 2>&1"
RESPONSE=`${TIMEOUT_CMD} bash -c "${CMD}"`
if [ ${?} -ne 0 ]; then
    # Try again with verbose on
    CMD="echo '${COMMAND}' | nc -v ${HOST} ${PORT} 2>&1"
    RESPONSE=`${TIMEOUT_CMD} bash -c "${CMD}"`
    if [ "${RESPONSE}" == "" ]; then
        RESPONSE="<empty output>"
    fi
    echo "CRITICAL - ${RESPONSE}"
    exit 2
fi

if [ ${EXACT} -eq 1 ]; then
    if [ "${RESPONSE}" != "${STRING}" ]; then
        echo "CRITICAL - Expected: ${STRING}, but instead received: ${RESPONSE}"
        exit 2
    else
        echo "OK - Expected response received (exact match): `echo ${RESPONSE} | grep -o \"${STRING}\"`"
        exit 0
    fi
else
    if ! `echo ${RESPONSE} | grep -q "${STRING}" 2>/dev/null`; then
        echo "CRITICAL - ${STRING} was not found in response"
        exit 2
    else
        echo "OK - Response matched string: `echo ${RESPONSE} | grep -o \"${STRING}\"`"
        exit 0
    fi
fi

