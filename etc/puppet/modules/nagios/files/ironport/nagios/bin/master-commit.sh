#!/usr/local/bin/bash
#==============================================================================
# master-commit.sh
#
# Verify nagios configuration, restart nagios, and notify IRC.
#
# 2011-03-16 jramache
#==============================================================================
PATH=/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/usr/local/ironport/nagios/bin
if `uname -s | grep Linux 1>/dev/null 2>/dev/null`; then
   MTIME_STAT_CMD='stat -c"%Y"'
else
   MTIME_STAT_CMD='stat -f%m'
fi
NAGIOS_RC_SCRIPT="/etc/init.d/nagios"
NAGIOS_PREFLIGHT_CMD="/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg"
IRONCAT="/usr/local/ironport/nagios/bin/ironcat.sh"
IRONCAT_ONCALL="/home/jramache/ironcat_oncall.sh"
VIEWONCALL="/usr/local/ironport/nagios/bin/viewoncall"
ONCALLREMINDER="/usr/local/ironport/nagios/bin/oncall_reminder.sh"
COMMIT_NOTIFICATION_EMAIL="stbu-monitoring-notifications@cisco.com"
LOCKAGE=`${MTIME_STAT_CMD} /usr/local/nagios/var/nagios.lock`
DELTACMD="/usr/local/ironport/akeos/bin/get_changes.py ${LOCKAGE}"
TRUE=0
FALSE=1
ALL_STOP=${FALSE}
CAT_MSG="$1"

if [ "${USER}" == "nagios" ]
then
    SUDO=""
else
    SUDO="sudo"
fi

echo
echo ">>>>> Checking nagios configuration (rc checkconfig)"
${SUDO} ${NAGIOS_RC_SCRIPT} checkconfig
if [ ${?} -ne 0 ]; then
    ALL_STOP=${TRUE}
fi

echo
echo ">>>>> Checking nagios configuration (preflight)"
OUT=`${SUDO} ${NAGIOS_PREFLIGHT_CMD}`
CODE=$?
printf "%b" "${OUT}" | grep -v Processing
if [ ${CODE} -ne 0 ]; then
    ALL_STOP=${TRUE}
fi

if [ ${ALL_STOP} -eq ${TRUE} ]; then
    echo ">>>>> Error: aborting commit due to nagios configuration errors."
    exit 1
fi

echo
echo ">>>>> Restarting nagios"
sudo ${NAGIOS_RC_SCRIPT} restart

if [ ${?} -ne 0 ]; then
    echo ">>>>>> Error: unexpected error during nagios restart."
    echo ">>>>>> MANUAL INTERVENTION MAY BE REQUIRED"
    exit 1
fi

echo
echo ">>>>> Sleeping for 2 seconds"
sleep 2

echo
echo ">>>>> Looking for nagios in process table"
if ! ps auxww |grep -- 'nagios -d' 2>/dev/null ; then
    echo ">>>>> Error: nagios is not running"
    echo ">>>>> MANUAL INTERVENTION IS REQUIRED"
    exit 1
fi

echo
echo ">>>>> Nagios is running. Notifying IRC..."
if [ "${CAT_MSG}" == "" ]
then
    ${IRONCAT} "${USER} committed nagios changes on `hostname`"
else
    ${IRONCAT} "${USER} committed nagios changes on `hostname` \"${CAT_MSG}\""
fi

echo
echo ">>>>> Send a similar notice to stbu-monitoring-notifications"
echo "${USER} committed nagios changes on `hostname`" | mail -s "Production monitoring deployed" ${COMMIT_NOTIFICATION_EMAIL}

#==============================================================================
# BEGIN AUTO DOWNTIME CHANGED ITEMS
#==============================================================================
#echo
#echo ">>>>> Collecting deltas"
#DELTAS=`sudo -u nagios ssh nagios@ops-mon-akeos1.vega.ironport.com "${DELTACMD}"`
#
#echo ">>>>> Iterating through deltas and applying 30m downtime."
#SERVICES=`for x in ${DELTAS}
#do
#    if [[ "$x" == *,Service,* ]]
#    then
#        echo $x | awk -F, '{ print $4 }'
#    fi
#done | sort | uniq`
#HOSTS=`for x in ${DELTAS}
#do
#    if [[ "$x" == *,Host,* ]]
#    then
#        echo $x | awk -F, '{ print $4 }'
#    fi
#done | sort | uniq`
#for s in $SERVICES
#do
#    x=`grep -A1 -e "service_description[[:space:]]${s}$" /usr/local/nagios/etc/services.cfg`
#    if [ "$x" != "" ]
#    then
#        y=`echo $x | tail -1`
#        if [[ "$y" == *hostgroup* ]]
#        then
#            groups=`echo $y | awk  '{ print $4 }'`
#            printf "%.150b ...\n" "Downtiming service [$s] for hostgroup(s) [$groups]"
#            OFS=$IFS
#            IFS=,
#            for g in $groups
#            do
#                z=`grep -A1 -e "[[:space:]]${g}$" /usr/local/nagios/etc/hostgroups.cfg`
#                hosts=`echo $z | awk '{ print $4 }'`
#                for h in $hosts
#                do
#                    sudo downtime -g service -s service -H $h -S $s -c "Automatic post-commit downtime." -u commit
#                done
#            done
#            IFS=$OFS
#        else
#            hosts=`echo $y | awk  '{ print $4 }'`
#            printf "%.150b ...\n" "Downtiming service [${s}] for host(s) [${hosts}]"
#            OFS=$IFS
#            IFS=,
#            for h in $hosts
#            do
#                sudo downtime -g service -s service -H $h -S $s -c "Automatic post-commit downtime." -u commit
#            done
#                
#            IFS=$OFS
#        fi
#        
#    fi
#done
#
#for h in $HOSTS
#do
#    echo "Downtiming host [$h] and services."
#    sudo downtime -g host -s host -H $h -c "Automatic post-commit downtime." -u commit
#    sudo downtime -g host -s service -H $h -c "Automatic post-commit downtime." -u commit
#done
#
#==============================================================================
# BEGIN AUTO DOWNTIME CHANGED ITEMS
#==============================================================================

echo
echo ">>>>> Nagios restart completed."

echo
echo ">>>>> On call configuration"
${VIEWONCALL}

echo
echo ">>>>> Sleeping for 5 minutes, then sending on call output to IRC (in bg)"
( sleep 360 && ${IRONCAT_ONCALL} ) &

if [ "`date +%A`" = "Friday" -a `date +%H` -ge 16 ]; then
    echo
    echo ">>>>> Also sending weekly reminder email since it's Friday afternoon (in bg)"
    ( sleep 360 && ${ONCALLREMINDER} prodops ) &
fi
if [ "`date +%A`" = "Tuesday" -a `date +%H` -ge 11 -a `date +%H` -le 14 ]; then
    echo
    echo ">>>>> Also sending weekly reminder email to dba,monops,netops,platops,storage since it's Tuesday morning (in bg)"
    ( sleep 360 && ${ONCALLREMINDER} dba ) &
    ( sleep 380 && ${ONCALLREMINDER} monops ) &
    ( sleep 400 && ${ONCALLREMINDER} netops ) &
    ( sleep 420 && ${ONCALLREMINDER} platops ) &
    ( sleep 430 && ${ONCALLREMINDER} platopskfa ) &
    ( sleep 440 && ${ONCALLREMINDER} storage ) &
fi
exit 0
