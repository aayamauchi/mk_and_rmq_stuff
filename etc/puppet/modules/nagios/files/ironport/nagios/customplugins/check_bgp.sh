#!/usr/local/bin/bash
#==============================================================================
# check_bgp.sh
#
# Check bgp route status
#
#    peer_count
#        alarm if number of peers drops below threshold
#
#    peer_state
#        alarm if state is not optimal (depends on check_bgp4.pl) for any
#
#    peer_route_size
#        alarm if routing table size changes by 10% or more over 15min for any
#
# 2013-08-13 jramache
#==============================================================================
HOST=
COMMUNITY=
TYPE=
WARNING_THRESHOLD=
CRITICAL_THRESHOLD=

# Peer routing table size threshold parameters
ROUTE_HISTORY_DIR="/tmp/bgp_peer_route_counts"
SIZE_AGE_WINDOW=900
MAX_HISTORY_AGE=$(( ${SIZE_AGE_WINDOW} * 2 ))
SIZE_PCT_CHANGE=.10

OID_PEER_IP_LIST="1.3.6.1.2.1.15.3.1.7"
OID_PEER_ROUTE_COUNT_BASE="1.3.6.1.4.1.9.9.187.1.2.4.1.1"
CHECK_BGP4_STATE="/usr/local/ironport/nagios/customplugins/check_bgp4.pl"

USAGE=$( cat <<EOM
Usage: `basename ${0}` -H host -C community -t check_type -w warning -c critical
           -H  host
           -C  snmp community string
           -t  check type: peer_count|peer_state|peer_route_size
           -w  warning threshold, if appliable
           -c  critical threshold, if applicable
EOM
)

OPTIONS=
while getopts ":H:C:t:w:c:" OPTIONS
do
    case ${OPTIONS} in
        H ) HOST="${OPTARG}";;
        C ) COMMUNITY="${OPTARG}";;
        t ) TYPE="${OPTARG}";;
        w ) WARNING_THRESHOLD=${OPTARG};;
        c ) CRITICAL_THRESHOLD=${OPTARG};;
        * ) echo "${USAGE}"
            exit 3;;
    esac
done
if [ "${HOST}" = "" ]; then
    echo "UNKNOWN - Missing host name or ip (-H)"
    echo "${USAGE}"
    exit 3
fi
if [ "${COMMUNITY}" = "" ]; then
    echo "UNKNOWN - Missing snmp community (-C)"
    echo "${USAGE}"
    exit 3
fi
if [ "${TYPE}" = "" ]; then
    echo "UNKNOWN - Missing check type (-t)"
    echo "${USAGE}"
    exit 3
fi

if [ "${TYPE}" = "peer_count" ]; then
    if [ "${WARNING_THRESHOLD}" = "" -o "${CRITICAL_THRESHOLD}" = "" ]; then
        echo "Warning (-w) and critical (-c) thresholds are required for ${TYPE}"
        exit 3
    fi
    if [ "${WARNING_THRESHOLD}" -eq "${WARNING_THRESHOLD}" 2>/dev/null ]; then
        if [ "${CRITICAL_THRESHOLD}" -eq "${CRITICAL_THRESHOLD}" 2>/dev/null ]; then
            WARNING_THRESHOLD=${WARNING_THRESHOLD}
            CRITICAL_THRESHOLD=${CRITICAL_THRESHOLD}
        else
            echo "Critical threshold is not a number"
            exit 3
        fi
    else
        echo "Warning threshold is not a number"
        exit 3
    fi
fi

is_validip()
{
    case "$*" in
        ""|*[!0-9.]*|*[!0-9]) return 1 ;;
    esac

    local IFS=.  ## local is bash-specific
    set -- $*

    [ $# -eq 4 ] &&
        [ ${1:-999} -le 255 ] && [ ${2:-999} -le 255 ] &&
        [ ${3:-999} -le 255 ] && [ ${4:-999} -le 254 ]
}

# SNMPv2-SMI::mib-2.15.3.1.7.92.60.249.17 = IpAddress: 92.60.249.17
# SNMPv2-SMI::mib-2.15.3.1.7.208.90.63.153 = IpAddress: 208.90.63.153
# SNMPv2-SMI::mib-2.15.3.1.7.212.187.138.209 = IpAddress: 212.187.138.209
PEER_IP_LIST=`snmpwalk -O T -v 2c -c "${COMMUNITY}" ${HOST} ${OID_PEER_IP_LIST} 2>/dev/null | grep -i 'ipaddress:' | awk '{print $NF}'`

if [ "${PEER_IP_LIST}" = "" ]; then
    echo "CRITICAL - Unable to retrieve peer ip addresses from ${HOST}"
    exit 2
fi

for IP in `echo "${PEER_IP_LIST}"`
do
    if ! is_validip "${IP}" ; then
        echo "CRITICAL - Invalid peer ip address: ${IP}\nPeer ip addresses returned:\n${PEER_IP_LIST}"
        exit 2
    fi
done

NEWLINE="
"
append_history()
{
    if [ "${NEW_HISTORY}" == "" ]; then
        NEW_HISTORY="${1}"
    else
        NEW_HISTORY="${NEW_HISTORY}${NEWLINE}${1}"
    fi
}

EXIT_CODE=0
MSG=
if [ "${TYPE}" == "peer_count" ]; then
    N_PEERS=`echo "${PEER_IP_LIST}" | wc -l`
    if [ ${N_PEERS} -le ${CRITICAL_THRESHOLD} ]; then
        MSG="Number of bgp peers: ${N_PEERS}, threshold: ${CRITICAL_THRESHOLD}"
        EXIT_CODE=2
    elif [ ${N_PEERS} -le ${WARNING_THRESHOLD} ]; then
        MSG="Number of bgp peers: ${N_PEERS}, threshold: ${WARNING_THRESHOLD}"
        EXIT_CODE=1
    else
        MSG="Number of bgp peers: ${N_PEERS}, threshold: ${WARNING_THRESHOLD}"
        EXIT_CODE=0
    fi
    MSG="${MSG}\n${PEER_IP_LIST}"

elif [ "${TYPE}" == "peer_state" ]; then
    MSG=
    C_MSG=
    W_MSG=
    U_MSG=
    O_MSG=
    for IP in `echo "${PEER_IP_LIST}"`
    do
        STATE=`${CHECK_BGP4_STATE} -H ${HOST} -C "${COMMUNITY}" -p ${IP}`
        case ${?} in
            2) EXIT_CODE=2
               C_MSG="${C_MSG}\n${STATE}"
               ;;
            1) if [ ${EXIT_CODE} -ne 2 ]; then
                   EXIT_CODE=1
               fi
               W_MSG="${W_MSG}\n${STATE}"
               ;;
            0) O_MSG="${O_MSG}\n${STATE}"
               ;;
            *) if [ ${EXIT_CODE} -ne 2 -a ${EXIT_CODE} -ne 1 ]; then
                   EXIT_CODE=3
               fi
               U_MSG="${U_MSG}\n${STATE}"
               ;;
        esac
    done

    MSG="${C_MSG}${W_MSG}${U_MSG}${O_MSG}\n"
    if [ "`echo ${MSG} | sed 's/[[:blank:]]*//g'`" = "" ]; then
        MSG="Could not find any active peers"
        EXIT_CODE=2
    else
        if [ ${EXIT_CODE} -ne 0 ]; then
            MSG="Issue with peer state${MSG}"
        else
            MSG="No issue with peer state${MSG}"
        fi
    fi

elif [ "${TYPE}" == "peer_route_size" ]; then
    if [ ! -d "${ROUTE_HISTORY_DIR}" ]; then
        mkdir "${ROUTE_HISTORY_DIR}" >/dev/null 2>&1
        if [ ${?} -ne 0 ]; then
            echo "CRITICAL - Unable to create history dir: ${ROUTE_HISTORY_DIR}"
            exit 2
        fi
    fi
    MSG=
    C_MSG=
    W_MSG=
    U_MSG=
    O_MSG=
    NOW=`date +%s`
    for IP in `echo "${PEER_IP_LIST}"`
    do
        HISTORY=
        NEW_HISTORY=
        LAST_CHECK=
        LAST_CHECK_TIME=
        LAST_CHECK_EXIT=
        THIS_EXIT=0
        HISTORY_FILE="${ROUTE_HISTORY_DIR}/${HOST}_${IP}"
        if [ -s "${HISTORY_FILE}" 2>/dev/null ]; then
            HISTORY=`cat "${HISTORY_FILE}"`
        else
            U_MSG="Could not find history"
            if [ ${EXIT_CODE} -ne 2 -a ${EXIT_CODE} -ne 1 ]; then
                EXIT_CODE=3
            fi
        fi
        OLD_IFS=${IFS}
        IFS=${NEWLINE}
        for L in ${HISTORY}
        do
            _DATA=`echo "${L}" | awk -F':' '{print $1}'`
            _TIME=`echo "${L}" | awk -F':' '{print $2}'`
            _EXIT=`echo "${L}" | awk -F':' '{print $3}'`
            _AGE=$(( ${NOW} - ${_TIME} ))
            if [ ${_AGE} -lt ${SIZE_AGE_WINDOW} ]; then
                append_history "${L}"
            else
                if [ "${LAST_CHECK}" == "" ]; then
                    if [ ${_AGE} -le ${MAX_HISTORY_AGE} ]; then
                        LAST_CHECK=${_DATA}
                        LAST_CHECK_TIME=${_TIME}
                        LAST_CHECK_EXIT=${_EXIT}
                        append_history "${L}"
                    fi
                elif [ ${_AGE} -le ${MAX_HISTORY_AGE} ]; then
                    append_history "${L}"
                fi
            fi
        done
        IFS=${OLD_IFS}
        COUNT=`snmpwalk -O T -v 2c -c "${COMMUNITY}" ${HOST} ${OID_PEER_ROUTE_COUNT_BASE}.${IP} | awk '{print $NF}'`
        if [ "${COUNT}" -eq "${COUNT}" ] 2>/dev/null; then
            if [ "${LAST_CHECK}" != "" ]; then
                # Compare current count with historical data
                DELTA=$(( ${COUNT} - ${LAST_CHECK} ))
                if [ ${DELTA} -lt 0 ]; then
                    ABS_DELTA=$(( ${DELTA} * -1 ))
                else
                    ABS_DELTA=${DELTA}
                fi
                MAX_CHANGE_DELTA=`echo "${LAST_CHECK} ${SIZE_PCT_CHANGE}" | awk '{ printf("%.0f", (($1 * $2) + .5));}'`
                if [ ${MAX_CHANGE_DELTA} -le 0 ]; then
                    MAX_CHANGE_DELTA=1
                fi
                if [ ${ABS_DELTA} -gt ${MAX_CHANGE_DELTA} ]; then
                    C_MSG="${C_MSG}\NCRITICAL - ${IP}: routes: ${COUNT}, delta: ${DELTA}"
                    THIS_EXIT=2
                    EXIT_CODE=2
                else
                    O_MSG="${O_MSG}\nOK - ${IP}: routes: ${COUNT}, delta: ${DELTA} (threshold: ${MAX_CHANGE_DELTA})"
                fi
            else
                O_MSG="${O_MSG}\nOK - ${IP}: routes: ${COUNT} (waiting for history)"
            fi

            # Update history
            if [ "${NEW_HISTORY}" == "" ]; then
                (echo "${COUNT}:${NOW}:${THIS_EXIT}" >"${HISTORY_FILE}") 2>/dev/null
            else
                (echo "${COUNT}:${NOW}:${THIS_EXIT}${NEWLINE}${NEW_HISTORY}" >"${HISTORY_FILE}") 2>/dev/null
            fi
            if [ ${?} -ne 0 ]; then
                U_MSG="Unable to create history file!"
                if [ ${EXIT_CODE} -ne 2 -a ${EXIT_CODE} -ne 1 ]; then
                    EXIT_CODE=3
                fi
            fi
        else
            C_MSG="CRITICAL - ${IP}: number of routes returned is nan: [`echo ${COUNT} | head -c 80`]\n${MSG}"
            EXIT_CODE=2
        fi
    done
    MSG="${C_MSG}${W_MSG}${U_MSG}${O_MSG}\n"
    DISPLAY_PCT=`echo ${SIZE_PCT_CHANGE} | awk '{printf("%.0f",($1 * 100))}'`
    case ${EXIT_CODE} in
          0) MSG="No issues (threshold: ${DISPLAY_PCT}% change over ${SIZE_AGE_WINDOW} sec)${MSG}" ;;
        1|2) MSG="Issue with one or more peers (threshold: ${DISPLAY_PCT}% change over ${SIZE_AGE_WINDOW} sec)${MSG}" ;;
          *) MSG="Monitoring glitch: ${MSG}" ;;
    esac
else
    echo "UNKNOWN - Invalid check type: ${TYPE} (-t)"
    echo "${USAGE}"
    exit 3
fi

MSG=`echo "${MSG}" | sed 's/\\\n$//g'`

if [ ${EXIT_CODE} -eq 2 ]; then
    printf "%b" "CRITICAL - ${MSG}\n"
    exit 2
elif [ ${EXIT_CODE} -eq 1 ]; then
    printf "%b" "WARNING - ${MSG}\n"
    exit 1
elif [ ${EXIT_CODE} -eq 3 ]; then
    printf "%b" "UNKNOWN - ${MSG}\n"
    exit 3
elif [ ${EXIT_CODE} -eq 0 ]; then
    printf "%b" "OK - ${MSG}\n"
    exit 0
else 
    printf "%b" "UNKNOWN - ${MSG}\n"
    exit 3
fi
