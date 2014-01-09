#!/usr/local/bin/bash
#
# Tim Spencer <tspencer@ironport.com>
# Mon Mar  6 16:55:03 PST 2006
#
# This script is different from the normal check_mtime script that we use
# because it has to look for a file with a format of importer-YEAR-MONTH-DAY
# that changes every day.
#
# usage:  check_importer_log.sh -w <seconds to warn at> -i <importer>
#              -d <directory> -h <hostname>
#     where importer is the start of the filename (avlog or phlog)
#     and directory is the directory that the avlog or phlog file is in
#     Alerting happens after 2x the warning
#
#  example: ./check_importer_log.sh -i avlog -w 2 -d
#==============================================================================
# 2012-05-01 jramache, made it work remotely from poller rather than locally
#                      also added -h option and timeout functionality
#==============================================================================
TIMEOUT=30
TIMEOUT_CMD="/usr/local/ironport/nagios/customplugins/timeout.pl -9 ${TIMEOUT}"

# some defaults
HOSTNAME=""
WARN=600
IMPORTER=""
DIR=""

# get arguments
while [ ! -z "$1" ] ; do
        if [ "$1" = "-h" ] ; then
		shift
		HOSTNAME="${1}"
	fi
        if [ "$1" = "-w" ] ; then
		shift
		WARN=${1}
	fi
	if [ "$1" = "-i" ] ; then
		shift
		IMPORTER="${1}"
	fi
	if [ "$1" = "-d" ] ; then
		shift
		DIR="${1}"
	fi
        shift
done

if [ "${HOSTNAME}" = "" ]; then
    echo "UNKNOWN - Missing a hostname"
    exit 3
fi

FILE="${DIR}"/"${IMPORTER}"-`TZ=GMT date +%F`
FILETIME="`${TIMEOUT_CMD} /usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOSTNAME} \"/usr/bin/stat -f%m '${FILE}' 2>/dev/null\" 2>&1`"
if [ "`echo \"${FILETIME}\" | sed 's/[[:space:]]*//g'`" = "" ]; then
    echo "CRITICAL - Error obtaining stat of ${FILE}"
    exit 2
fi
if [ ${FILETIME} -eq ${FILETIME} 2>/dev/null ]; then
    FILETIME=${FILETIME}
else
    echo "${FILETIME}" | grep -i '^timeout' >/dev/null 2>&1
    if [ ${?} -eq 0 ]; then
        echo "CRITICAL - Timeout: aborted ssh command (waited for ${TIMEOUT} seconds)"
    else
        ERROR_MESG="`echo \"${FILETIME}\" | cut -c1-100`...[output truncated]..."
        echo "CRITICAL - ${ERROR_MESG}"
    fi
    exit 2
fi

TIME=`date +%s`

# figure out lag and alert times
LAG=`expr "${TIME}" - "${FILETIME}"`
ALERT=`expr "${WARN}" \* 2`

# debug foo
#echo FILE is $FILE
#echo FILETIME is $FILETIME
#echo TIME is $TIME
#echo WARN is $WARN
#echo LAG is $LAG
#echo ALERT is $ALERT

# warn, alert, OK!
if [ "${LAG}" -gt "${ALERT}" ] ; then
	echo "CRITICAL - ${FILE} has not been changed in ${LAG} seconds"
	exit 2
fi

if [ "${LAG}" -gt "${WARN}" ] ; then
	echo "WARNING - ${FILE} has not been changed in ${LAG} seconds"
	exit 1
fi

echo "OK - ${FILE} has been changed in $LAG seconds"
exit 0
