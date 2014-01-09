#!/usr/local/bin/bash
HOST=$1
DESC=$2
STATE=$3

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/bin

export NAGIOS_HOSTADDRESS=$HOST

DESC=`/bin/echo ${DESC} | /usr/bin/tr "[:upper:]" "[:lower:]" | /usr/bin/tr " " "_" | /usr/bin/tr -d /`

SCRIPT="/usr/local/ironport/nagios/notification_handler/${STATE}"

if [ "${DESC}" == "host" ]
then
	SCRIPT="${SCRIPT}/${HOST}"
else
	if [ -x "${SCRIPT}/${HOST}_${DESC}" ]
	then
		SCRIPT="${SCRIPT}/${HOST}_${DESC}"
	else
		SCRIPT="${SCRIPT}/${DESC}"
	fi
fi

if [[ ( -x "${SCRIPT}" ) && ( ! -d "${SCRIPT}" ) ]]
then
	OUT=`${SCRIPT} 2>&1`
	echo ===== `date` ===== >> /tmp/handler.out
	echo ${SCRIPT} ${HOST} >> /tmp/handler.out
	printf "%s" "${OUT}" >> /tmp/handler.out
	echo >> /tmp/handler.out
	printf "%s" "${OUT}"
        echo
fi

# run the host audit
# DISABLED UNTIL FURTHER NOTICE BY JEFF ON 9/12/2013
#echo "host-audit.sh ${NAGIOS_HOSTADDRESS} >/dev/null 2>&1" | at now >/dev/null 2>/dev/null
