#!/usr/local/bin/bash
#==============================================================================
# check_cisco_cpu.sh
#
# 2013-08-16 jramache
#==============================================================================
HOST=
COMMUNITY=
TYPE=
WARNING_THRESHOLD=
CRITICAL_THRESHOLD=
WARNING_THRESHOLD_1M=
CRITICAL_THRESHOLD_1M=
WARNING_THRESHOLD_5M=
CRITICAL_THRESHOLD_5M=

OID_PROC_INDEX="1.3.6.1.4.1.9.9.109.1.1.1.1.2"
OID_PROC_NAME="1.3.6.1.2.1.47.1.1.1.1.7"
OID_PROC_1M="1.3.6.1.4.1.9.9.109.1.1.1.1.7"
OID_PROC_5M="1.3.6.1.4.1.9.9.109.1.1.1.1.8"

USAGE=$( cat <<EOM
Usage: `basename ${0}` -H host -C community -t device_type -w warning -c critical
           -H  host
           -C  snmp community string
           -t  device type: asr9k
           -w  warning threshold, if appliable (1m,5m,15m)
           -c  critical threshold, if applicable (1m,5m,15m)
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
    echo "UNKNOWN - Missing device type (-t)"
    echo "${USAGE}"
    exit 3
fi
WARNING_THRESHOLD_1M=`echo ${WARNING_THRESHOLD} | awk -F, '{print $1}'`
WARNING_THRESHOLD_5M=`echo ${WARNING_THRESHOLD} | awk -F, '{print $2}'`
CRITICAL_THRESHOLD_1M=`echo ${CRITICAL_THRESHOLD} | awk -F, '{print $1}'`
CRITICAL_THRESHOLD_5M=`echo ${CRITICAL_THRESHOLD} | awk -F, '{print $2}'`

# get index
# snmpwalk -O T -v 2c -c ******** rtr-brd-01-lon5.lon5.sco.cisco.com  1.3.6.1.4.1.9.9.109.1.1.1.1.2
#     SNMPv2-SMI::enterprises.9.9.109.1.1.1.1.2.2 = INTEGER: 52690955
#     SNMPv2-SMI::enterprises.9.9.109.1.1.1.1.2.18 = INTEGER: 26932192
#     SNMPv2-SMI::enterprises.9.9.109.1.1.1.1.2.2082 = INTEGER: 35271015
#     SNMPv2-SMI::enterprises.9.9.109.1.1.1.1.2.2098 = INTEGER: 8695772

O_MSG=""
C_MSG=""
W_MSG=""
U_MSG=""

IFS="
"
for PROC_ENTITY in `snmpwalk -O T -v 2c -c ${COMMUNITY} ${HOST} ${OID_PROC_INDEX}`
do
    idx0=`echo ${PROC_ENTITY} | awk -F= '{print $1}' | grep -o '[^.]*$' | sed 's/[[:blank:]]*$//g'`
    idx1=`echo ${PROC_ENTITY} | awk '{print $NF}'`
    # name
    name=`snmpwalk -O T -v 2c -c ${COMMUNITY} ${HOST} ${OID_PROC_NAME}.${idx1} | awk -F'"' '{print $(NF-1)}'`
    # 1 min avg cpu
    cpu1m=`snmpwalk -O T -v 2c -c ${COMMUNITY} ${HOST} ${OID_PROC_1M}.${idx0} | awk '{print $NF}'`
    # 5m min avg cpu
    cpu5m=`snmpwalk -O T -v 2c -c ${COMMUNITY} ${HOST} ${OID_PROC_5M}.${idx0} | awk '{print $NF}'`

    #echo "${name}: ${cpu1m}/${cpu5m} (1min/5min)"
    if [ ${cpu1m} -gt ${CRITICAL_THRESHOLD_1M} ]; then
        C_MSG="${C_MSG}CRITICAL - ${name}: ${cpu1m} (1min) threshold: ${CRITICAL_THRESHOLD_1M}\n"
    elif [ ${cpu1m} -gt ${WARNING_THRESHOLD_1M} ]; then
        W_MSG="${W_MSG}WARNING - ${name}: ${cpu1m} (1min) threshold: ${WARNING_THRESHOLD_1M}\n"
    else
        O_MSG="${O_MSG}OK - ${name}: ${cpu1m} (1min)\n"
    fi

    if [ ${cpu5m} -gt ${CRITICAL_THRESHOLD_5M} ]; then
        C_MSG="${C_MSG}CRITICAL - ${name}: ${cpu5m} (5min) threshold: ${CRITICAL_THRESHOLD_5M}\n"
    elif [ ${cpu5m} -gt ${WARNING_THRESHOLD_5M} ]; then
        W_MSG="${W_MSG}WARNING - ${name}: ${cpu5m} (5min) threshold: ${WARNING_THRESHOLD_5M}\n"
    else
        O_MSG="${O_MSG}OK - ${name}: ${cpu5m} (5min)\n"
    fi
done

if [ "${C_MSG}" != "" ]; then
    MSG="CRITICAL - cpu usage exceeds threshold\n"
    EXIT_CODE=2
elif [ "${W_MSG}" != "" ]; then
    MSG="WARNING - cpu usage exceeds threshold\n"
    EXIT_CODE=1
elif [ "${U_MSG}" != "" ]; then
    MSG="UNKNOWN - cpu usage exceeds threshold\n"
    EXIT_CODE=3
else
    MSG="OK - cpu usage below threshold\n"
    EXIT_CODE=0
fi

MSG="${MSG}${C_MSG}${W_MSG}${U_MSG}${O_MSG}"
printf "%b" "${MSG}"
exit ${EXIT_CODE}
