#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/bin

if [ "" == "${NAGIOS_SERVICESTATE}" ]
then
# is a host issue.
	DESC=${NAGIOS_HOSTNAME}
	STATE=${NAGIOS_HOSTSTATE}
	TYPE=${NAGIOS_HOSTSTATETYPE}
	ATTEMPT=${NAGIOS_HOSTATTEMPT}
else
	DESC=${NAGIOS_SERVICEDESC}
	STATE=${NAGIOS_SERVICESTATE}
	TYPE=${NAGIOS_SERVICESTATETYPE}
	ATTEMPT=${NAGIOS_SERVICEATTEMPT}
        MAX=${NAGIOS_MAXSERVICEATTEMPTS}
        HALF=`echo ${MAX} / 2 | /usr/bin/bc`
        #hook to trigger ironcat spew, if we're about to have a pageable event.
        if [[ ( "${STATE}" == "CRITICAL" ) && ( "${TYPE}" == "SOFT" ) && \
                (( "${NAGIOS_HOSTDOWNTIME}" == "0" ) && \
                ( "${NAGIOS_SERVICEDOWNTIME}" == "0" )) ]]
        then
            HOST=${NAGIOS_HOSTNAME}
            ESCA=`nagios_escalation.py -H "${HOST}" -S "${DESC}"`
            if [[ ( "${ESCA}" == *pager* ) ]]
            then
                URL="https://mon.ops.ironport.com/nagios/cgi-bin/extinfo.cgi?type=2&host=${HOST}&service=${DESC}"
                if [ "${ATTEMPT}" == "1" ]
                then
                    echo "${HOST}/${DESC} [${ATTEMPT}/${MAX}] '${NAGIOS_SERVICEOUTPUT}'. ${URL}" | wall
                elif [ "${ATTEMPT}" -gt "${HALF}" ]
                then
                    ironcat.sh "${HOST}/${DESC} [${ATTEMPT}/${MAX}] '${NAGIOS_SERVICEOUTPUT}'. ${URL}"
                fi
            fi
        fi

fi

#env > /tmp/handler.out
#set >> /tmp/handler.out

DESC=`/bin/echo ${DESC} | /usr/bin/tr "[:upper:]" "[:lower:]" | /usr/bin/tr " " "_" | /usr/bin/tr -d /`

if [ "${TYPE}" == "HARD" ]
then
	SCRIPT="/usr/local/ironport/nagios/event_handler/${STATE}/HARD"
else
	SCRIPT="/usr/local/ironport/nagios/event_handler/${STATE}/SOFT/${ATTEMPT}"
fi

#echo script: ${SCRIPT} >> /tmp/handler.out
if [ "${NAGIOS_SERVICESTATE}" == "" ]
then
	SCRIPT="${SCRIPT}/${NAGIOS_HOSTNAME}"
else
	if [ -x "${SCRIPT}/${NAGIOS_HOSTNAME}_${DESC}" ]
	then
		SCRIPT="${SCRIPT}/${NAGIOS_HOSTNAME}_${DESC}"
	else
		SCRIPT="${SCRIPT}/${DESC}"
	fi
fi

if [[ ( -x "${SCRIPT}" ) && ( ! -d "${SCRIPT}" ) ]]
then
	OUT=`${SCRIPT} 2>&1`
	echo [`date`] ${SCRIPT} ${NAGIOS_HOSTNAME} >> /tmp/handler.out
	printf "%s" "${OUT}" >> /tmp/handler.out
	printf "%s" "${OUT}"
        echo >> /tmp/handler.out
        printf "%s" "${SCRIPT}\n${OUT}" | nagsub.py >/dev/null 2>&1
else
        echo [`date`] \(no\) ${SCRIPT} ${NAGIOS_HOSTNAME} >> /tmp/handler.out
        nagsub.py >/dev/null 2>&1
fi

echo
