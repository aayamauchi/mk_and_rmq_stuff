#!/usr/local/bin/bash
#==============================================================================
# This script checks the importer latency using DrData.sh on the requested host
#
# Tim Spencer <tspencer@ironport.com>
# Mon Mar  6 18:51:18 PST 2006
#
# usage:   check_importer_latency.sh <host to run DrData on> <warning level>
#     warning level is the # of seconds behind it will be before it starts
#     warning.  It alerts at 2x warning
#
# 20110505 jramache, * Timeout hack added
# 20120502 jramache, * Timeout hack removed because the cluster check (parent)
#                      implements a timeout mechanism and this one was causing
#                      some interference
#                    * Added exec to ssh subprocess to enable the cluster
#                      check to more easily kill this script after timeout
#                    * Additional error checks
#                    * Alerting is based on max lag now, rather than the first
#                      value encountered above threshold
#                    * Minor cosmetic changes
#==============================================================================
HOST=${1}
WARN=${2}
ALERT=$(( ${WARN} * 2 ))

PATH=/bin:/usr/bin:/usr/local/bin

OUT=`exec ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOST} "/usr/local/ironport/toc/bin/DrData.sh -timport 2>&1" 2>&1`

if [ "${OUT}" = "" ]; then
    echo "UNKNOWN - No output from DrData.sh script"
    exit 3
fi

echo "${OUT}" | grep '== Importer Status ==' >/dev/null 2>&1
if [ ${?} -ne 0 ]; then
    ERROR_MESG="`echo \"${OUT}\" | cut -c1-512`"
    echo "UNKNOWN - Unexpected output: ${ERROR_MESG}"
    exit 3
fi

OUT=`echo "${OUT}" | grep ^Lag | awk '{print $5}'`
IFS="
"
MAX=0
for LINE in ${OUT}
do
    if [ ${LINE} -eq ${LINE} 2>/dev/null ]; then
        VALUE=`echo ${LINE} | bc`
        if [ ${VALUE} -gt ${MAX} ]; then
            MAX=${VALUE}
        fi
    else
        echo "UNKNOWN - Unable to interpret non-numerical lag data: ${LINE}"
        exit 3
    fi
done

if [ ${MAX} -gt ${ALERT} ]; then
    echo "CRITICAL - an importer is ${MAX} seconds behind (worst offender)"
    exit 2
elif [ ${MAX} -gt ${WARN} ]; then
    echo "WARNING - an importer is ${MAX} seconds behind (worst offender)"
    exit 1
fi

if [ ${?} -eq 0 ] ; then
    echo "OK - importers are all less than ${WARN} seconds behind"
fi
exit ${?}

