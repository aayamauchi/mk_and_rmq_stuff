#!/usr/local/bin/bash
#==============================================================================
# dig_server_query.sh
#
# Query a specific dns server using dig utility. Requires dig.
#
# 20130718 jramache
#==============================================================================
DIG=`which dig 2>/dev/null`
if [ "${DIG}" = "" ]; then
    echo "CRITICAL - dig command not found"
    exit 2
fi

USAGE=$( cat <<EOM
Usage: `basename ${0}` -t timeout -s dns_server -H hostname [-h] [-v]
           -t  Timeout in seconds
           -s  DNS server name to query
           -H  Host name to check in DNS
           -h  Help
           -v  Turn on debugging output
EOM
)

TIMEOUT=
DNS_SERVER=
HOSTNAME=
VERBOSE=0

OPTIONS=
while getopts ":t:s:H:hv" OPTIONS
do
    case ${OPTIONS} in
        t ) TIMEOUT="${OPTARG}";;
        s ) DNS_SERVER="${OPTARG}";;
        H ) HOSTNAME="${OPTARG}";;
        h ) echo "${USAGE}"
            exit 0;;
        v ) VERBOSE=1;;
        * ) echo "${USAGE}"
            exit 0;;
    esac
done

if [ "${TIMEOUT}" = "" ]; then
    echo "CRITICAL - missing timeout argument"
    echo "${USAGE}"
    exit 3
fi

if [ "${DNS_SERVER}" = "" ]; then
    echo "CRITICAL - missing dns server argument"
    echo "${USAGE}"
    exit 3
fi

if [ "${HOSTNAME}" = "" ]; then
    echo "CRITICAL - missing hostname argument"
    echo "${USAGE}"
    exit 3
fi

RESPONSE=`${DIG} @${DNS_SERVER} ${HOSTNAME} +time=${TIMEOUT} +tries=1 2>&1`
RET_CODE=${?}

if [ ${RET_CODE} -ne 0 ]; then
    # Parse dig error
    RESPONSE=`echo "${RESPONSE}" | tail -1`
else
    # Parse server response
    RESPONSE=`echo "${RESPONSE}" | grep '>>HEADER<<' | egrep -o '(status:[[:blank:]]*[^[:blank:],]*)' | awk '{print $NF}'`
fi

# --- FROM MAN PAGE ---
# Dig return codes are:
#     0: Everything went well, including things like NXDOMAIN 
#     1: Usage error 
#     8: Couldn't open batch file 
#     9: No reply from server 
#     10: Internal error 
#
case ${RET_CODE} in
    0) if [ "${RESPONSE}" = "NOERROR" ]; then
           echo "OK - Response: NOERROR for ${HOSTNAME}"
           exit 0
       else
           echo "CRITICAL - Response: ${RESPONSE} for ${HOSTNAME}"
           exit 2
       fi
       ;;
    1) echo "UNKNOWN - usage error: ${RESPONSE}"
       exit 3;;
    8) echo "UNKNOWN - unable to open batch file: ${RESPONSE}"
       exit 3;;
    9) echo "CRITICAL - No reply from server: ${RESPONSE}"
       exit 2;;
    10) echo "UNKNOWN - internal error: ${RESPONSE}"
        exit 3;;
    *) echo "UNKNOWN - return code ${RET_CODE}: ${RESPONSE}"
       exit 3;;
esac
