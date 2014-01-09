#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/sbin

MASTER=ops-mon-nagios1.vega.ironport.com
AKEOS=ops-mon-akeos1.vega.ironport.com
EXTERNAL=ops-mon-nagios1.rs.ironport.com
BASE=/usr/local/nagios

if [ "$USER" != "nagios" ]
then
    echo "Please run as nagios user"
    exit
fi

if [ -e ${BASE}/var/nagios.lock ]
then
    pid=`cat ${BASE}/var/nagios.lock`
    if kill -0 ${pid} 2>/dev/null
    then 
        # nagios is running
        exit
    fi
fi


# State
rsync --archive --rsh=/usr/bin/ssh ${MASTER}:${BASE}/var/retention.dat ${BASE}/var/retention.dat #>/dev/null 2>&1

# Mirror config and external poller config (for emergency pager list)
rsync --archive --delete --delete-after --rsh=/usr/bin/ssh ${MASTER}:${BASE}/etc-ops-mon-nagios1.vega/ ${BASE}/etc/ #>/dev/null 2>&1
rsync --archive --delete --delete-after --rsh=/usr/bin/ssh ${AKEOS}:${BASE}/etc-ops-mon-nagios1.rs/ ${BASE}/etc-external #>/dev/null 2>&1

exit

