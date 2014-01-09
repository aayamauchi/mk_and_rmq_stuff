#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/bin/

if [ "" == "${NAGIOS_SERVICESTATE}" ]
then
# is a host issue.
	DESC=${NAGIOS_HOSTADDRESS}
	STATE=${NAGIOS_HOSTSTATE}
else
	DESC=${NAGIOS_SERVICEDESC}
	STATE=${NAGIOS_SERVICESTATE}
fi

DESC=`/bin/echo ${DESC} | /usr/bin/tr "[:upper:]" "[:lower:]" | /usr/bin/tr " " "_" | /usr/bin/tr -d /`

SCRIPT="/usr/local/ironport/nagios/notification_handler/${STATE}"

if [ "${NAGIOS_SERVICESTATE}" == "" ]
then
	SCRIPT="${SCRIPT}/${NAGIOS_HOSTADDRESS}"
else
	if [ -x "${SCRIPT}/${NAGIOS_HOSTADDRESS}_${DESC}" ]
	then
		SCRIPT="${SCRIPT}/${NAGIOS_HOSTADDRESS}_${DESC}"
	else
		SCRIPT="${SCRIPT}/${DESC}"
	fi
fi

if [[ ( -x "${SCRIPT}" ) && ( ! -d "${SCRIPT}" ) ]]
then
	OUT=`${SCRIPT} 2>&1`
	echo ===== `date` ===== >> /tmp/handler.out
	echo ${SCRIPT} ${NAGIOS_HOSTADDRESS} >> /tmp/handler.out
	printf "%s" "${OUT}" >> /tmp/handler.out
	echo >> /tmp/handler.out
	printf "%s" "${OUT}"
        echo
fi

echo "========================================"
if [ "${NAGIOS_SERVICESTATE}" != "" ]
then
    echo "Command run as nagios user:"
    COMMAND=`/usr/local/ironport/nagios/bin/nagios_command.py -H ${NAGIOS_HOSTADDRESS} -S "${NAGIOS_SERVICEDESC}" 2>&1`
    echo ${COMMAND}
fi

echo "========================================"
if [ "${NAGIOS_SERVICESTATE}" != "" ]
then
    echo "Nagios escalation tree for this service check:"
    COMMAND=`/usr/local/ironport/nagios/bin/nagios_escalation.py -H ${NAGIOS_HOSTADDRESS} -S "${NAGIOS_SERVICEDESC}" 2>&1`
    if [ "${COMMAND}" == "" ]
    then
        echo NONE
    else
        /usr/bin/printf "%s" "${COMMAND}"
        echo
    fi
fi

echo "========================================"
if [ "${NAGIOS_SERVICESTATE}" != "" ]
then
    echo "Event handler scripts for this service check:"
    COMMAND=`/usr/bin/find /usr/local/ironport/nagios/event_handler/ -name "snmp"`
    if [ "${COMMAND}" == "" ]
    then
        echo NONE
    else
        /usr/bin/printf "%s" "${COMMAND}"
    fi
fi

# run the host audit
# DISABLED UNTIL FURTHER NOTICE BY JEFF ON 9/12/2013
#echo "host-audit.sh ${NAGIOS_HOSTADDRESS} \"${NAGIOS__HOSTOS}\" >/dev/null 2>&1" | at now >/dev/null 2>/dev/null
