#!/usr/local/bin/bash
#
# Basic script by Tim Spencer <tspencer@ironport.com>
# Thu Mar  2 21:08:22 PST 2006
#
# Expanded and error/argument checking added 7/13/07
# Emily Gladstone Cole <emily@ironport.com>
#
# you can find out the args for this by doing something like this:
# snmpwalk -c <rocommstring> -v 2c HOST | grep PID
#  Where HOST is the name of the host that it's running on
#  And PID is the pid of the process (previously gathered with ps)
# Then look at the hrSWRunName for the process, and the
# hrSWRunParameters for the arguments.  Have fun!
#

# step through and get values for command line arguments
# echo usage if incorrect argument found

PATH=/bin:/usr/bin:/usr/local/bin

while [ $# -gt 0 ]; do
    case "$1" in
    -H)  Host="$2"; shift;;
    -C)  Community="$2"; shift;;
    -p)  Process="$2"; shift;;
    -a)  Arguments="$2"; shift;;
    -n)  MemoryCheck="no"; shift;;
    -w)  Warn="$2"; shift;;
    -c)  Critical="$2"; shift;;
    --) shift; break;;
    *)  break;; # terminate while loop
    esac
    shift
done

# Check for not-set variables that we need to have
if [ x${Host} = x ] || [ x${Process} = x ]; then
    echo "usage: $0 -H host
    -C ROCommString
    -p process
"
    exit 1
fi

process_table='1.3.6.1.2.1.25.4.2.1'
index_table='1.3.6.1.2.1.25.4.2.1.1'
run_name_table='1.3.6.1.2.1.25.4.2.1.2'
run_path_table='1.3.6.1.2.1.25.4.2.1.4'
run_param_table='1.3.6.1.2.1.25.4.2.1.5'
proc_mem_table='1.3.6.1.2.1.25.5.1.1.2' # Kbytes
proc_cpu_table='1.3.6.1.2.1.25.5.1.1.1' # Centi sec of CPU
proc_run_state='1.3.6.1.2.1.25.4.2.1.7'

PID=`snmpwalk -c ${Community} -v 2c ${Host} $run_name_table | grep ${Process} | head -1`
if [ "${PID}" == "" ]
then
    echo 0
    exit
fi
PID=`echo ${PID} | cut -f 1 -d \  | cut -f 2 -d .`
MEM=`snmpwalk -c ${Community} -v 2c ${Host} ${proc_mem_table}.${PID} | cut -f 4 -d \ `
MEM=`echo "${MEM} * 1024" | bc`
echo ${Process}Mem:${MEM}
