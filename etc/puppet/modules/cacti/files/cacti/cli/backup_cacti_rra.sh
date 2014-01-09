#!/bin/bash

IOnice='ionice -c3'
PRnice='nice -n+19'
JOBMAXTIME='230m'
LOGFILE='/usr/share/cacti/log/rsync.log'
BACKUPSOURCE='ops-cacti-db-m1.vega.ironport.com::rra'
BACKUPDESTINATION='/data/rra'
RSYNCCMD="/usr/bin/rsync -a --stats --inplace --whole-file $BACKUPSOURCE $BACKUPDESTINATION"

echo "$(date +%Y-%m-%dT%H:%M%S) Start RRA backup" >> $LOGFILE
type nice > /dev/null 2>&1 && RSYNCLINE="$RSYNCLINE $PRnice"
RSYNCLINE="$RSYNCLINE $RSYNCCMD"
# double check other rsync
ps aux | grep -v grep | grep -Esq "^$(id -un)[[:space:]]+[0-9]+.*$RSYNCCMD"
if [ $? -eq 0 ] ; then
        echo "$(date +%Y-%m-%dT%H:%M%S) backup script is being run already. Exiting" >> $LOGFILE
        exit 0
fi
# run job and store pid of job
($RSYNCLINE >> $LOGFILE 2>&1) & export rsync_pid=$!
# try to set idle IO priority for rsync
type ionice > /dev/null 2>&1 && sudo $IOnice -p $rsync_pid > /dev/null 2>&1 &
# run watcher to kill job after JOBMAXTIME
(sleep $JOBMAXTIME > /dev/null 2>&1 ; kill $rsync_pid > /dev/null 2>&1 && echo "$(date +%Y-%m-%dT%H:%M%S) RRA backup was terminated using time watcher" >> $LOGFILE) & export rsync_watcher=$!
# kill watcher if job completed successfull
wait $rsync_pid && pkill -P $rsync_watcher > /dev/null 2>&1 && echo "$(date +%Y-%m-%dT%H:%M%S) RRA backup completed" >> $LOGFILE
