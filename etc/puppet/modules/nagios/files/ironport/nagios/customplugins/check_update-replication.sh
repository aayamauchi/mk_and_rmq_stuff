#!/usr/local/bin/bash

MONMASTER="ops-mon-nagios1.vega.ironport.com"

STR_PROD_FAILURES=`ssh nagios@${MONMASTER} "for x in \\\`ls /tmp/update-repl.prod.*pid\\\`; do T=\\\`date +%s\\\`; M=\\\`stat -f%m \\\$x\\\`; AGE=\\\`echo \"\\\$T - \\\$M\" | bc\\\`; if [ \\\$AGE -gt 3 ]; then echo \\\$x; fi; done" 2>/dev/null`
FAILCOUNT_ALL=`ssh nagios@${MONMASTER} "for x in \\\`ls /tmp/update-repl.*pid\\\`; do T=\\\`date +%s\\\`; M=\\\`stat -f%m \\\$x\\\`; AGE=\\\`echo \"\\\$T - \\\$M\" | bc\\\`; if [ \\\$AGE -gt 3 ]; then echo \\\$x; fi; done | wc -l" 2>/dev/null`

FAILCOUNT_ALL=`echo "${FAILCOUNT_ALL}" | awk '{print $1}' | bc`

if [ "${STR_PROD_FAILURES}" = "" ]; then
    echo "No prod replication failures detected, ${FAILCOUNT_ALL} total failures"
    if [ "${FAILCOUNT_ALL}" -gt 0 ]; then
        ssh nagios@${MONMASTER} "ls /tmp/update-repl*pid"
        exit 1
    else
        exit 0
    fi
fi

echo "${FAILCOUNT_ALL} replication failures detected"
ssh nagios@${MONMASTER} "ls /tmp/update-repl*pid"
exit 2

