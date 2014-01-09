#!/usr/local/bin/bash
#==============================================================================
# last_log_entry_age.sh
#
# Checks the age (in seconds) of the last log entry for a given pattern, and 
# compares this to critical and warning thresholds.
#
# If pattern is not found it could be due to a log rotation. In this case,
# a grace period setting is allowed whereby OK is returned if the last
# rotation occurred no more than grace seconds ago. It requires that the log
# rotation entry (a pattern can be passed as an arg) occurs in the first 5
# lines of the log file.
#
# CAUTION: This was initially created to parse syslog (local*.log) files and
#          therefore assumes that the date and time appear first on each log
#          line in the following format: Nov 15 14:11:24
#
# To improve performance when dealing with huge log files: rewrite in python,
# saving last file position in /tmp and then seeking to last position on next
# check (after first checking to see that log was not rotated: in other words,
# if logfilesize < lastpos).
#
# 2011-11-15 jramache
# 2012-04-24 jramache, added grace period since last log rotation
# 2012-06-21 jramache, date/time parsing works on either fbsd or linux now
#==============================================================================
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

NAGIOS_WARNING=
NAGIOS_CRITICAL=

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to determine time of last log entry"
ROTATE_PATTERN="logfile turned over"
GRACE=300

USAGE=$( cat << EOM
Usage: `basename ${0}` -h host -l logfile -p pattern -r pattern -g seconds -c seconds -w seconds [-v]
           -h  Host where log file resides
           -l  Full path to log file
           -p  Pattern to grep for in log file (warning: special chars may not be escaped, test first.)
           -r  Log rotate pattern to grep for if primary pattern not found
           -g  Grace period in seconds if pattern not found (i.e., age since log rotation)
           -c  Critical threshold (seconds): age of last pattern entry in log
           -w  Warning threshold (seconds): age of last pattern entry in log
           -v  Turn on debugging output
EOM
)

OPTIONS=
while getopts ":h:l:p:r:g:c:w::v" OPTIONS
do
    case ${OPTIONS} in
        h ) HOSTNAME="${OPTARG}";;
        l ) LOG="${OPTARG}";;
        p ) PATTERN="${OPTARG}";;
        r ) ROTATE_PATTERN="${OPTARG}";;
        g ) GRACE="${OPTARG}";;
        c ) NAGIOS_CRITICAL="${OPTARG}";;
        w ) NAGIOS_WARNING="${OPTARG}";;
        v ) VERBOSE=1;;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE};;
    esac
done

if [ ${VERBOSE} ]; then
    set -x
fi

if [ -z "${NAGIOS_WARNING}" -o -z "${NAGIOS_CRITICAL}" ]; then
   echo "${USAGE}"
   exit ${EXIT_CODE}
fi

if [ ! -z "${NAGIOS_WARNING}" -a ! -z "${NAGIOS_CRITICAL}" ]; then
   if [ `echo "${NAGIOS_CRITICAL} <= ${NAGIOS_WARNING}" | bc 2>/dev/null` -eq 1 ]; then
      echo "`basename ${0}`: error: critical threshold must be greater than warning threshold"
      exit ${EXIT_CODE}
   fi
fi

if [ "x${PATTERN}x" = "xx" ]; then
      echo "`basename ${0}`: error: you must supply a pattern to search for"
      exit ${EXIT_CODE}
fi

ParseTime() {
    # Convert log entry time to unix time (seconds since epoch).
    # A log entry line is passed as an argument.
    STR_TIME=`echo "${1}" | awk '{print $1,$2,$3}' 2>/dev/null`
    _U_TIME=
    if `uname -s | grep Linux 1>/dev/null 2>/dev/null`; then
        _U_TIME=`date --date="${STR_TIME}" +%s 2>/dev/null`
    else
        _U_TIME=`date -j -f "%b %e %T" "${STR_TIME}" +%s 2>/dev/null`
    fi
}

# Look for the last entry of PATTERN
LAST_LOG_ENTRY="`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOSTNAME} \"grep '${PATTERN}' ${LOG} 2>/dev/null | tail -1\" 2>/dev/null`"
if [ "x${LAST_LOG_ENTRY}x" = "xx" ]; then
    # Pattern not found, so determine if log was rotated recently (falls within GRACE period)
   PATTERN="${ROTATE_PATTERN}"
    LAST_LOG_ENTRY="`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOSTNAME} \"head -5 ${LOG} | grep '${PATTERN}' 2>/dev/null | tail -1\" 2>/dev/null`"
    if [ "x${LAST_LOG_ENTRY}x" = "xx" ]; then
        INFO="Neither the pattern nor a log rotation pattern were found in the log file"
    else
        ParseTime "${LAST_LOG_ENTRY}"
        if [ ${?} -ne 0 ] 2>/dev/null; then
            INFO="Unable to parse time of the last log rotation entry"
            EXIT_CODE=${STATE_CRIT}
        else
            T_LOG=${_U_TIME}
            T_NOW=`date +%s`
            T_AGE=$(( ${T_NOW} - ${T_LOG} ))
            if [ ${T_AGE} -gt ${GRACE} ]; then
                INFO="Pattern not found in log file and time since last log rotation exceeds grace period of ${GRACE} seconds"
                EXIT_CODE=${STATE_CRIT}
            else
                INFO="Pattern not found, but time since last log rotation falls under grace period of ${GRACE} seconds"
                EXIT_CODE=${STATE_OK}
            fi
        fi
    fi
else
    # Pattern found, determine if the age of last entry falls under threshold
    ParseTime "${LAST_LOG_ENTRY}"
    if [ ${?} -ne 0 ] 2>/dev/null; then
        INFO="Unable to parse log entry time"
        EXIT_CODE=${STATE_CRIT}
    else
        T_LOG=${_U_TIME}
        T_NOW=`date +%s`
        T_AGE=$(( ${T_NOW} - ${T_LOG} ))
        if [ ${T_AGE} -ge ${NAGIOS_CRITICAL} ]; then
            INFO="Last log entry was ${T_AGE} seconds ago (crit threshold: ${NAGIOS_CRITICAL})"
            EXIT_CODE=${STATE_CRIT}
        elif [ ${T_AGE} -ge ${NAGIOS_WARNING} ]; then
            INFO="Last log entry was ${T_AGE} seconds ago (warn threshold: ${NAGIOS_WARNING})"
            EXIT_CODE=${STATE_WARN}
        else
            INFO="Last log entry was ${T_AGE} seconds ago"
            EXIT_CODE=${STATE_OK}
        fi
    fi
fi
case ${EXIT_CODE} in
    ${STATE_OK}   ) echo "OK - ${INFO}";;
    ${STATE_WARN} ) echo "WARNING - ${INFO}";;
    ${STATE_CRIT} ) echo "CRITICAL - ${INFO}";;
    ${STATE_UNKN} ) echo "UNKNOWN - ${INFO}";;
    *             ) echo "UNKNOWN - ${INFO}";;
esac

exit ${EXIT_CODE}