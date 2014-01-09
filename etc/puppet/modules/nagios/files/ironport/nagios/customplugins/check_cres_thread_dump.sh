#!/bin/sh
# 
# check_cres_thread_dump.sh
# 
# If CPU is high - do a full JVM thread dump and look for a certain string 
# (default "UnifiedClassLoader.getResourceLocally" )- within the latest dump 
# Michael Gavartin (mgavarti@cisco.com) 9/12/09
# https://it-tickets.ironport.com/Ticket/Display.html?id=106926
#
# If CPU is high - generates an alarm if a certain string 
# - default "UnifiedClassLoader.getResourceLocally" - is present in the thread dump  
#
# 1. Checks the CPU on the CRES App server (check_snmp_cpu)
# 2. If CPU above CRITICAL:
#    2.1 Finds PID and current subdirectory of JVM 
#    2.2 Determines the length of postx.log 
#    2.3 Sends kill -3 for a full thread dump
#    2.4 Sleeps 5 sec to make sure the dump is complete
#    2.4 Determines the new log file length, calculates the number of new lines
#    2.5 Looks for a certain string in the tail of the log file 
#    2.6 Alarms if such string is found
# 
# Usage:
# cres_java_string.sh -H HOSTADDRES -p SNMP_PASSWORD -s STRING -w WARN -c CRITICAL 

PATH=/bin:/usr/bin:/sbin:/usr/sbin
WORK_DIR=/usr/local/ironport/nagios/customplugins/
usage="usage: $0 -H HOSTNAME -p SNMP_PASSWORD -s STRING -w WARN -c CRITICAL"

# Defaults: 

String="UnifiedClassLoader.getResourceLocally"
Warn="85"
Critical="95"

# step through and get values for command line arguments
# echo usage if incorrect argument found

while [ $# -gt 0 ]; do
    case "$1" in
    -H)  Hostname="$2"; shift;;
    -p)  SnmpPassword="$2"; shift;;
    -s)  String="$2";shift;;
    -w)  Warning="$2"; shift;;
    -c)  Critical="$2"; shift;;
    --)	shift; break;;
    -*)
        echo >&2 $usage
        exit 1;;
    *)  break;;	# terminate while loop
    esac
    shift
done

ssh_cmd="ssh -q -oBatchMode=yes -oStrictHostKeyChecking=no nagios@${Hostname}"

# Exit if user did not define a Hostname or Password
if [ x${Hostname} = x ]; then
    echo "You must specify a Hostname!"
    echo $usage
    exit 3
else
    if [ x${SnmpPassword} = x ]; then
        echo "You must specify a SNMP Password!"
        echo $usage
        exit 3
    fi
fi

# check CPU 

cmd="${WORK_DIR}check_snmp_cpu.py -H ${Hostname} -p ${SnmpPassword} -w ${Warning} -c ${Critical}"
CPUoutput=`${cmd}` 
cpu_exit=$?

if [ ${cpu_exit} -eq 0 ]; then
   echo "OK - ${CPUoutput}"
   exit 0
else
    if [ ${cpu_exit} -eq 3 ]; then
        # CPU Check Status Unknown
        echo $CPUoutput
        exit 3
    else
       if [ ${cpu_exit} -eq 1 ]; then
          echo "OK - ${CPUoutput}. CPU warning, JVM thread dump not checked"
          exit 0
       fi
    fi
fi

# CPU critical - check the string

ps_cmd="${ssh_cmd} ps awwx | grep jre/bin/java | grep -v grep | tr '/' ' '"
ps_java=`${ps_cmd}`
pid=`echo ${ps_java} | awk '{print $1}' `
subdir=`echo ${ps_java} | awk '{print $7}'`

log_file="/cust/postxnet/${subdir}/log/postx.log"
log_lines_before=`${ssh_cmd} wc -l ${log_file} | awk '{print $1}'`
kill_response=`ssh nagios@${Hostname} sudo kill -3 ${pid}`

# Wait for the dump to complete
sleep 5 

log_lines_after=`${ssh_cmd} wc -l ${log_file} | awk '{print $1}'`

# Calculate the length of the last thread dump
len=$((log_lines_after - log_lines_before))
if [ ${len} -lt 1 ]; then
    # probably log file rolled over while sleeping - will check the next time
    echo "UNKNOWN" 
    exit 3
fi
search_cmd="${ssh_cmd} tail -${len} ${log_file} | grep ${String} "
search_line=`${search_cmd}`

if [ $? -ne 0 ]; then
     # String not found
     echo "OK - CPU above critical but there is no ${String} in JVM thread dump"
     exit 0
else
     echo "CRITICAL - CPU above critical and ${String} found in JVM thread dump"
     exit 2
fi
 