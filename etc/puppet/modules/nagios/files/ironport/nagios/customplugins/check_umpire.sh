#!/usr/local/bin/bash
#==============================================================================
# check_umpire.sh
#
# General purpose umpire (graphite) plugin.
#
# 20130709 jramache
#==============================================================================
CURL=`which curl 2>/dev/null`
if [ "${CURL}" = "" ]; then
    echo "Missing curl utility"
    exit 2
fi

USAGE=$( cat <<EOM
Usage: `basename ${0}` -H umpire-server -T target_host -u umpire-user -p umpire-password -m metric -c critical_threshold -r range [-i] [-v] | -h
           -H  Umpire server name or ip
           -T  Target host pertaining to metrics
           -u  Umpire user (http auth)
           -p  Umpire user password (http auth)
           -m  Metric to check
           -c  Critical threshold
           -r  Range (in seconds)
           -i  Invert check (use min instead of max)
           -h  Help
           -v  Turn on debugging output
EOM
)

MAX_OR_MIN="max"
OK_STR="below"
CRITICAL_STR="above"

UMPIRE_SERVER=
TARGET_HOST=
UMPIRE_USER=
UMPIRE_PASSWORD=
METRIC=
CRITICAL_THRESHOLD=
RANGE=
VERBOSE=0

OPTIONS=
while getopts ":H:T:u:p:m:c:r:ihv" OPTIONS
do
    case ${OPTIONS} in
        H ) UMPIRE_SERVER="${OPTARG}";;
        T ) TARGET_HOST="${OPTARG}";;
        u ) UMPIRE_USER="${OPTARG}";;
        p ) UMPIRE_PASSWORD="${OPTARG}";;
        m ) METRIC="${OPTARG}";;
        c ) CRITICAL_THRESHOLD="${OPTARG}";;
        r ) RANGE="${OPTARG}";;
        i ) MAX_OR_MIN="min"
            OK_STR="above"
            CRITICAL_STR="below";;
        h ) echo "${USAGE}"
            exit 0;;
        v ) VERBOSE=1;;
        * ) echo "${USAGE}"
            exit 0;;
    esac
done

if [ "${UMPIRE_SERVER}" = "" ]; then
    echo "Missing umpire server (-H)"
    echo "${USAGE}"
    exit 2
fi

if [ "${TARGET_HOST}" = "" ]; then
    echo "Missing target host (-T)"
    echo "${USAGE}"
    exit 2
fi

if [ "${UMPIRE_USER}" = "" -o "${UMPIRE_PASSWORD}" = "" ]; then
    echo "Missing umpire user (-u) or password (-p)"
    echo "${USAGE}"
    exit 2
fi

if [ "${METRIC}" = "" ]; then
    echo "Missing metric (-m): nothing to check"
    echo "${USAGE}"
    exit 2
fi

if [ "${CRITICAL_THRESHOLD}" = "" ]; then
    echo "Missing critical threshold (-c)"
    echo "${USAGE}"
    exit 2
fi

if [ "${RANGE}" = "" ]; then
    echo "Missing range (-r)"
    echo "${USAGE}"
    exit 2
fi

if [ ${VERBOSE} -eq 1 ]; then
    set -x
fi

# Transform target in various ways for optional replacement in metric
HOST=`echo ${TARGET_HOST} | awk -F'.' '{print $1}'`
DOMAIN=`echo ${TARGET_HOST} | awk -F'.' '{print $2}'`
REV_TARGET="${DOMAIN}.${HOST}"
LAS_CARBON_TARGET=`echo ${TARGET_HOST} | tr '.' '_' | sed 's/las1/las/'`

# Replace any transformed targets in metric if any exist
METRIC=`echo ${METRIC} | sed "s/%TARGET_HOST%/${TARGET_HOST}/g"`
METRIC=`echo ${METRIC} | sed "s/%REV_TARGET%/${REV_TARGET}/g"`
METRIC=`echo ${METRIC} | sed "s/%LAS_CARBON_TARGET%/${LAS_CARBON_TARGET}/g"`

# Retrieve value and http code
RESPONSE=`${CURL} -s -w "%{http_code}" -u${UMPIRE_USER}:${UMPIRE_PASSWORD} -o - "http://${UMPIRE_SERVER}/check?metric=${METRIC}&${MAX_OR_MIN}=${CRITICAL_THRESHOLD}&range=${RANGE}" | tr '\n' '|'`
VALUE=`echo ${RESPONSE} | awk -F'|' '{print $1}' | awk -F':' '{print $2}' | sed 's/\}$//'`
HTTP_CODE=`echo ${RESPONSE} | awk -F'|' '{print $2}'`

# Translate http code into nagios status
if [ "${HTTP_CODE}" = "200" ]; then
    echo "OK - Current value ${VALUE} is ${OK_STR} threshold of ${CRITICAL_THRESHOLD}"
    exit 0
elif [ "${HTTP_CODE}" = "500" ]; then
    echo "CRITICAL - Current value ${VALUE} is ${CRITICAL_STR} threshold of ${CRITICAL_THRESHOLD}"
    exit 2
else
    echo "UNKNOWN - Unexpected response from umpire: `echo ${RESPONSE} | head -c 80`"
    exit 3
fi
