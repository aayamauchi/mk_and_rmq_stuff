#!/usr/local/bin/bash

TICKETS=`/usr/local/ironport/nagios/bin/rt-tickets.sh "$NAGIOS_HOSTNAME" "$NAGIOS_SERVICEDESC" "$NAGIOS_SERVICEOUTPUT"`
FOUND=`echo ${TICKETS} | /bin/grep Found`


if [[ "${FOUND}" != "" && "${NAGIOS_CONTACTEMAIL}" == "sysops-work@it-tickets.ironport.com" ]]
then
    #echo "Tickets exist, don't open a new one."
    exit
fi

NOTIFICATION_HANDLER=`/usr/local/ironport/nagios/customplugins/notification_handler.sh`

/usr/bin/printf "%b" "***** Nagios  *****

Notification Type: $NAGIOS_NOTIFICATIONTYPE #$NAGIOS_NOTIFICATIONNUMBER
Service: $NAGIOS_SERVICEDESC
Host: $NAGIOS_HOSTNAME
Address: $NAGIOS_HOSTADDRESS
State: $NAGIOS_SERVICESTATE
Duration: $NAGIOS_SERVICEDURATION
Info: $NAGIOS_SERVICEOUTPUT
$NAGIOS_LONGSERVICEOUTPUT
`if [ "${NAGIOS_SERVICEACKAUTHOR}" != "" ]
then
echo "[$NAGIOS_SERVICEACKAUTHOR] $NAGIOS_SERVICEACKCOMMENT"
fi`

Date/Time: $NAGIOS_LONGDATETIME

https://mon.soma.ironport.com/monitor/
https://cacti-www1.soma.ironport.com/cacti/graph_view.php?action=preview&filter=$NAGIOS_HOSTADDRESS
http://awesome.ironport.com/twiki/bin/view/Main/SysopsGw
http://awesome.ironport.com/twiki/bin/view/Main/GwHost`echo \`echo $NAGIOS_HOSTNAME | cut -c1 | tr [:lower:] [:upper:]\`\`echo $NAGIOS_HOSTNAME | sed -e 's/[0-9,.].*//g' | sed -e 's/-//' | sed -e 's/^.//'\`` 
http://awesome.ironport.com/twiki/bin/view/Main/GwService` echo \`echo $NAGIOS_SERVICEDESC | cut -c1 | tr [:lower:] [:upper:]\`\`echo $NAGIOS_SERVICEDESC | sed "s/^.//"\` | sed -e 's/[-,_,., ]//g'`

${NOTIFICATION_HANDLER}
`if [[ ( "${NOTIFICATION_HANDLER}" == *Queue* ) ]]
then
/usr/bin/printf "%s" "=====================
Ticket Search URL
${TICKETS}"
fi`
" | /bin/mail -s "** $NAGIOS_NOTIFICATIONTYPE alert - $NAGIOS_HOSTNAME/$NAGIOS_SERVICEDESC is $NAGIOS_SERVICESTATE **" $NAGIOS_CONTACTEMAIL

