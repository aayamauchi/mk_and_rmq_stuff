#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/nagios/bin


M15=`nagiostats -c /usr/local/nagios/etc/nagios.cfg -dNUMSVCPSVCHK15M -m`

if [ $M15 -lt 7500 ]
then
    echo "Services received in last 15m: $M15" | mail 4153096791@messaging.sprintpcs.com
fi
