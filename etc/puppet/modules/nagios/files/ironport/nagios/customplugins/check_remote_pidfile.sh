#!/usr/local/bin/bash
PATH=/bin:/usr/bin:/usr/local/bin

if [ $# -lt 2 ]; then
    echo "syntax: ${0} <host> <pidfile>"
    exit 1
fi

PIDEXIT=`ssh -i ~nagios/.ssh/id_rsa nagios@${1} "if [ -r ${2} ]; then PID=\\\`/usr/bin/head -1 ${2} 2>/dev/null | /usr/bin/awk 'BEGIN {FS=\"[^0-9]\"}{print \\\$1}' 2>/dev/null | /usr/bin/tr -d '\n' 2>/dev/null\\\`; echo -n \\\${PID}' '; ps -p \\\${PID} >/dev/null 2>&1; echo \\\${?}; else echo \"missing pidfile\"; fi" 2>&1`

PID=`echo ${PIDEXIT} | awk '{ print $1 }'`
EXIT=`echo ${PIDEXIT} | awk '{ print $NF }'`

# First of all, is the pid numeric?
if [ ${PID} -eq ${PID} ] 2>/dev/null; then
    # Next, was the pid running?
    if [ ${EXIT} -eq 0 ] 2>/dev/null; then
        echo "OK - ${1}:${2} pid ${PID} running."
        exit 0
    else
        echo "CRITICAL - ${1}:${2} pid ${PID} not running"
        exit 2
    fi
else
    echo "CRITICAL - ${1}:${2} unexepected error: ${PIDEXIT}"
    exit 2
fi

