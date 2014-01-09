#!/usr/bin/env bash

#Script to find longrunning processes matching regexp
#Ticket: https://jira.sco.cisco.com/browse/MONOPS-1414
#Author: Bogdan Berezovyi <bberezov@cisco.com>

EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNK=3

USAGE=$( cat << EOM
Script to find longrunning processes matching regexp.

E.g: We can find all processes matching python.*haddop belonging to user corpus and running more than 1 day, and rise critical
if the number of such processes is greater than 4.

$: sudo -u nagios check_longrunning_process.sh -H stage-ars-hdn1.vega.ironport.com -u corpus -p python.*hadoop -c 4 -w 2 -r 1 -t day
OK: 0 procs matching python.*hadoop older than 1 days (critical: 4 procs)

Usage: `basename ${0}` -H hostname -n process_name -u user -r runtime -t time_unit -c critical  [-w warning] [-h]
        -H|--host      Hostname
        -u|--user      Process belongs to user
        -p|--pname     Search process with name
        -r|--runtime   Threshold in timeunits
        -t|--tunit     Timeunit for threshold count: minutes,hours,days are acceptable
        -c|--critical  Critical number of old processes
        -w|--warning   Warning number of old processes
        -h|--help      Help
EOM
)


while [ $# -gt 0 ]; do
    case "$1" in
    -H|--host)      hostname="$2"; shift;;
    -u|--user)      user="$2"; shift;;
    -p|--pname)     pname="$2"; shift;;
    -r|--runtime)   runtime="$2"; shift;;
    -t|--tunit)     tunit="$2"; shift;;
    -c|--critical)  critical="$2"; shift;;
    -w|--warning)   warning="$2"; shift;;
    -h|--help)  echo "${USAGE}"; exit $EXIT_UNK;;
    --) shift; break;;
    *)  echo "${USAGE}"; exit $EXIT_UNK;; # terminate while loop
    esac
    shift
done

if [[ -z ${hostname} || -z ${user} || -z ${pname} || -z ${critical} || -z ${runtime} || -z ${tunit} ]]; then
        echo "${USAGE}"
        exit $EXIT_UNK
fi

case $tunit in
   minute) seconds=`echo $runtime * 60| bc` ;;
   hour)   seconds=`echo $runtime * 60 *60| bc` ;;
   day)    seconds=`echo $runtime * 24 * 60 *60 | bc` ;;
   *)      echo "${USAGE}"; exit EXIT_UNK ;;
esac

ssh_user='nagios'
now=`date +%s`
threshold_epoch=`echo $now - $seconds| bc`
oldproc=0

system=`ssh -l $ssh_user $hostname uname`
if [[ $system == 'Linux' ]]; then
    psout='-o ppid,lstart,comm'
elif [[ $system == 'FreeBSD' ]]; then
    psout='-o pid,lstart,command'
else 
    echo "UNKNOWN operating system"
    exit $EXIT_UNK
fi

while read line; do
    stime=`echo $line |awk '{print $2,$3,$4,$5,$6}'`
    stime_epoch=`date -d "$stime" +%s`
    [[ $stime_epoch -le $threshold_epoch ]] && oldproc=$((oldproc + 1))
done < <(ssh -l $ssh_user $hostname "ps -U $user $psout | grep '$pname'")

if [[ $oldproc -ge $critical ]]; then 
    echo "CRITICAL: $oldproc procs matching '$pname' older than $runtime ${tunit}s (critical: $critical procs)"
    exit $EXIT_CRIT
elif [[ -n $warning && $oldproc -ge $warning ]]; then
    echo "WARNING: $oldproc procs matching '$pname' older than $runtime ${tunit}s (warning: $warning procs)"
    exit $EXIT_WARN
else
    echo "OK: $oldproc procs matching '$pname' older than $runtime ${tunit}s (critical: $critical procs)"
    exit $EXIT_OK
fi


