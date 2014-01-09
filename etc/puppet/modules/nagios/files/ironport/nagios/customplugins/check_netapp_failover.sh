#!/usr/local/bin/bash
#==============================================================================
# check_netapp_failover.sh
#
# Nagios check for clustered netapp failover setting and state.
# If the result is 5, this reflects a state of failure.
# All other results reflect the Clustered Failover setting.
#
# Return codes and their meaning:
#         0 (ok)
#         1 (warning)
#         2 (critical)
#         3 (unknown)
#
# 2011-04-11 jramache
#==============================================================================
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"

# Passed to this script
SNMP_COMMUNITY=
NETAPP=

# Netapp clustered failover configuration settings. See RT:130549 for details.
OID="1.3.6.1.4.1.789.1.2.3.1.0"

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to determine failover state!"

# Attempt to force P1 issue in Jira for critical alerts by setting
# both Impact and Urgency to 1 (in notification_server syntax).
TICKET_PRIORITY="[##i1##][##u1##]"

USAGE=$( cat << EOM
Usage: `basename ${0}` -C snmp_community -H hostname [-v] [-h]
           -C  SNMP Community String
           -H  Netapp Hostname
           -h  Help
           -v  Turn on debugging output
EOM
)

OPTIONS=
while getopts ":C:H::hv" OPTIONS
do
    case ${OPTIONS} in
        C ) SNMP_COMMUNITY="${OPTARG}";;
	H ) NETAPP="${OPTARG}";;
        h ) echo "${USAGE}"
            exit ${EXIT_CODE};;
        v ) VERBOSE=1;;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE};;
    esac
done

if [ ${VERBOSE} ]; then
    set -x
fi

# Command check
COMMANDS="snmpget expr"
for CMD in ${COMMANDS}; do
    which "${CMD}" 1>/dev/null 2>/dev/null
    if [ ${?} -ne 0 ]; then
        echo "Error: missing basic command: ${CMD}"
        exit ${EXIT_CODE}
    fi
done

if [ -z "${SNMP_COMMUNITY}" -o -z "${NETAPP}" ]; then
   echo "${USAGE}"
   exit ${EXIT_CODE}
fi


# Query for failover setting or state
SNMPCMD="snmpget -O T -v 2c -c '${SNMP_COMMUNITY}' ${NETAPP} ${OID}"
SNMPRESULT=`eval "${SNMPCMD}" 2>/dev/null`

if [ ${?} -eq 0 ]; then
    VALUE=`expr "${SNMPRESULT}" : '.*INTEGER: \(.*\)'`
    case "${VALUE}" in
        "1" ) EXIT_CODE=${STATE_OK}
              INFO="Clustered failover not configured" ;;
        "2" ) EXIT_CODE=${STATE_OK}
              INFO="Clustered failover enabled" ;;
        "3" ) EXIT_CODE=${STATE_WARN}
              INFO="Clustered failover disabled" ;;
        "4" ) EXIT_CODE=${STATE_WARN}
              INFO="Clustered failover take over by partner is disabled" ;;
        "5" ) EXIT_CODE=${STATE_CRIT}
              INFO="Clustered failover: this node has been taken over!" ;;
    esac
fi

case ${EXIT_CODE} in
    ${STATE_OK}   ) echo "OK - ${INFO}";;
    ${STATE_WARN} ) echo "WARNING - ${INFO}";;
    ${STATE_CRIT} ) echo "CRITICAL - ${INFO} ${TICKET_PRIORITY}";;
    ${STATE_UNKN} ) echo "UNKNOWN - ${INFO}";;
    *             ) echo "UNKNOWN - ${INFO}";;
esac

exit ${EXIT_CODE}