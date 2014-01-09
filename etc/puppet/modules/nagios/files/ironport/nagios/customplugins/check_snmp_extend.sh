#!/usr/local/bin/bash

# Nagios "check" for querying output of scripts
# from remote servers via SNMP "extend" mechanism.
# 
# Author Michal Ludvig <michal@logix.cz> (c) 2006
#        http://www.logix.cz/michal/devel/nagios
# 


# Took what Michal had and expanded the crap out of it
# Michael Lindsey <mlindsey@ironport.com>

. /usr/local/nagios/libexec/utils.sh || exit 3

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/customplugins

SNMPGET=snmpget
TIMEOUT=timeout.pl
CUT=cut

HOST=$1
shift
NAME=$1
shift
SNMP=$1
shift
CRIT=$1
shift
WARN=$1

if [ "${CRIT}" == "-" ]; then CRIT=""; fi
if [ "${WARN}" == "-" ]; then WARN=""; fi

#echo `date`: $0 $HOST $NAME $SNMP $CRIT $WARN>> /tmp/extend.out

test "${HOST}" -a "${NAME}" || {
    echo "Attention: HOST or NAME is not defined!"
    echo "Exit with UNKNOWN STATE."
    echo "Usage:"
    echo "check_snmp_extend.sh  <host> <service> <snmp_string> <warning> <critical>"
    exit $STATE_UNKNOWN
}

test "${HOST}" -a "${NAME}" || exit $STATE_UNKNOWN

#RESULT=$(snmpget -m ALL -v2c -c ${SNMP} -OvQn ${HOST} NET-SNMP-EXTEND-MIB::nsExtendOutputFull.\"${NAME}\" 2>&1)
OUTPUT=$(${TIMEOUT} -9 45 ${SNMPGET} -t 15 -v2c -c ${SNMP} -OvQn ${HOST} .1.3.6.1.4.1.8072.1.3.2.3.1.2.\"${NAME}\" 2>&1)

RESULT=$(/bin/echo ${OUTPUT} | ${CUT} -d\" -f2)

STATUS=$(/bin/echo ${OUTPUT} | ${CUT} -d\  -f1)

case "$STATUS" in
	OK|WARNING|CRITICAL|UNKNOWN)
		CODE=$(eval "/bin/echo \$STATE_$STATUS")
		TEXT=${OUTPUT}
		;;
	*)
		CODE=$STATE_UNKNOWN
                TEXT=${OUTPUT}
		;;
esac

if [ "${CRIT}${WARN}" != "" ]
then
	if [ "${WARN}" == "" ]; then WARN=1000000000; fi
	if [ "${CRIT}" == "" ]; then CRIT=1000000000; fi

	NUMBER=`echo ${RESULT} | ${CUT} -d. -f1`

	if [ ${NUMBER} -eq ${NUMBER} 2> /dev/null ]; then
	#check that result is a number!

	if [ $(echo "${RESULT} >= ${WARN}" | /usr/bin/bc) -eq 1 ]
	then
		if [  $(echo "${RESULT} < ${CRIT}" | /usr/bin/bc) -eq 1 ]
		then
			TEXT="WARNING - ${HOST} ${NAME} status: ${RESULT} > ${WARN}"
			CODE=$STATE_WARNING
		fi
	fi
	if [ $(echo "${RESULT} >= ${CRIT}" | /usr/bin/bc) -eq 1 ]
	then
		TEXT="CRITICAL - ${HOST} ${NAME} status: ${RESULT} > ${CRIT}"
		CODE=$STATE_CRITICAL
	fi
	if [ $(echo "${RESULT} < ${WARN}" | /usr/bin/bc) -eq 1 ]
	then
		if [ $(echo "${RESULT} < ${CRIT}" | /usr/bin/bc) -eq 1 ]
		then
			TEXT="OK - ${HOST} ${NAME} status: ${RESULT}"
			CODE=$STATE_OK
		fi
	fi
	fi

fi

if [ "${CODE}" == "${STATE_UNKNOWN}" ]
then
    if [ "${NAME}" == "mailq" ]
    then 
        echo "$OUTPUT" | grep -q 'Mail system is down' && {
            CODE=$STATE_CRITICAL
            TEXT="CRITICAL - ${HOST} ${NAME} status: ${OUTPUT}"
            }
    else
        TEXT="UNKNOWN - ${HOST} ${NAME} status: ${OUTPUT}"
    fi
fi

printf "%b" "${TEXT}"
echo
exit ${CODE}
