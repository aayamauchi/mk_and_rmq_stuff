#!/usr/local/bin/bash

VOLS=`/usr/local/bin/snmpwalk -OvU -v 1 -c $2 $1 .1.3.6.1.4.1.789.1.5.4.1.10 | /bin/grep -v snapshot | /bin/grep -v "/\.\." | /bin/grep /vol/ | /bin/awk -F \" '{ print $2 }'`


for vol in ${VOLS}
do
  SQLquery="select service_names.command_line from service_names, hosts, services where service_names.command_line like '%snmp_disk-netapp%${vol}%' and hosts.name like '%${1}%' and hosts.host_id = services.host_id and services.servicename_id = service_names.servicename_id"
  SQL=`/bin/echo ${SQLquery} | /usr/bin/mysql -N -u monarch -pgwrk monarch`
  if [ "${SQL}" == "" ]
  then
    PROBLEMS="$PROBLEMS$vol "
    SHORTvol=`/bin/echo ${vol} | /bin/awk -F / '{ print $3 }'`/
    SQLquery="insert into service_names values (null, 'ip_snmp_netapp_disk-${SHORTvol}', NULL, (select servicetemplate_id from service_templates where name = 'ip-netapp-service'), (select command_id from commands where name='snmp_disk-netapp'), 'snmp_disk-netapp!${vol}', (select tree_id from escalation_trees where name='service-nopaging_openticket'), NULL, NULL) on duplicate key update name='ip_snmp_netapp_disk-${SHORTvol}'"
    SQLtwo="insert into services values (null, (select host_id from hosts where name='${1}'), (select servicename_id from service_names where name='ip_snmp_netapp_disk-${SHORTvol}'), (select servicetemplate_id from service_templates where name = 'ip-netapp-service'), NULL, (select tree_id from escalation_trees where name='service-nopaging_openticket'), 1, (select command_id from commands where name='snmp_disk-netapp'), 'snmp_disk-netapp!${vol}', null)"
    /bin/echo ${SQLquery} | /usr/bin/mysql -N -u monarch -pgwrk monarch
    /bin/echo ${SQLquery} | /usr/bin/mysql -h stage-mon.ops.ironport.com -N -u monarch -pgwrk monarch
    /bin/echo ${SQLtwo} | /usr/bin/mysql -N -u monarch -pgwrk monarch
  fi

done

if [ "${PROBLEMS}" == "" ]
then
  echo "No unmonitored /vol/ partitions"
  exit 0
else
  echo Unmonitored partitions: $PROBLEMS
  exit 2
fi
