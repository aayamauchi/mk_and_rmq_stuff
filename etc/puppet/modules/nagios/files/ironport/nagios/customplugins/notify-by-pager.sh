#!/usr/local/bin/bash
# Short and simple script for short and simple pager messages.

PATH=/bin:/usr/bin:/usr/local/bin
if [ "$NAGIOS_HOSTNAME" == "" ]
then
    NAGIOS_HOSTNAME=$1
    NAGIOS_SERVICEDESC=$2
    NAGIOS_CONTACTEMAIL=$3
    OUTPUT=$4
else
    OUTPUT="${NAGIOS_HOSTOUTPUT}${NAGIOS_SERVICEOUTPUT}"
fi

SHORTHOST=`echo ${NAGIOS_HOSTNAME} | sed 's/\.ironport.com//g'`

if [ "${NAGIOS_SERVICEDESC}" == "" ]
then
    printf "%b" "${SHORTHOST}
${NAGIOS_HOSTOUTPUT}" | mail -s "${SHORTHOST}" ${NAGIOS_CONTACTEMAIL}
else
    printf "%b" "${SHORTHOST}/${NAGIOS_SERVICEDESC}
${NAGIOS_SERVICEOUTPUT}" | mail -s "${SHORTHOST}/${NAGIOS_SERVICEDESC}" ${NAGIOS_CONTACTEMAIL}
fi
