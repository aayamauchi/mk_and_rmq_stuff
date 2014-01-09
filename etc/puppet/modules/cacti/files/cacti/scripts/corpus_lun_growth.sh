#!/bin/sh
#==============================================================================
# corpus_lun_growth.sh
#
# Monitor daily growth rate of the Corpus master DB LUN.
# Data samples are retrieved via get_cacti_kpi.py.
#
# Return codes and their meaning:
#         0 (ok)
#         1 (warning)
#         2 (critical)
#         3 (unknown)
#
# Output:
#     Nagios (default), one of:
#         OK - Corpus master DB LUN growth rate: X
#         WARNING - Corpus master DB LUN growth rate: X
#         CRITICAL - Corpus master DB LUN growth rate: X
#         UNKNOWN - Unable to determine Corpus master DB LUN growth rate
#     Cacti (-c):
#         kbytes_day:N  (where N is the amount of growth in KBytes)
#
# NOTE: If you add anything to this script, set ERRORS=1 (or non-zero)
#       appropriately to exit out in a predictable way when things go boom.
#
# 2010-03-15 jramache
#==============================================================================
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"

#------------------------------
# Nagios thresholds
#------------------------------
# Growth rate, in KBytes (0 means unset!)
NAGIOS_WARNING=0
NAGIOS_CRITICAL=0

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
ERRORS=0

# Base time parameters (in seconds) for kpi sample gathering.
MOST_RECENT_SAMPLE="-600"
SAMPLE_WINDOW_SIZE="1800"
GROWTH_PERIOD="86400"

OPTIONS=
while getopts ":chv" OPTIONS
do
    case ${OPTIONS} in
        c ) CACTI_OUTPUT=1;;
        h ) echo "${USAGE}"
            exit ${EXIT_CODE};;
        v ) VERBOSE=1;;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE};;
    esac
done

if [ ${VERBOSE} ]; then
    set -x
fi

LUN_DEVICE="mpath0"
# The cacti pollers have a different/non-standard path for get_cacti_kpi.py.
KPI_CMD="/data/cacti/scripts/get_cacti_kpi.py"
# The normal (in awesome_server) path to get_cacti_kpi.py
#KPI_CMD="/usr/local/ironport/awesome_server/bin/get_cacti_kpi.py"
KPI="${KPI_CMD} --product=corpus --purpose=dbm --environment=prod -D 'ucd/net - Hard Drive Space' -S 'hdd_used' -n '%${LUN_DEVICE}%' --last"

INFO="Unable to determine Corpus master DB LUN (${LUN_DEVICE}) growth rate"

# command check
COMMANDS="awk bc ${KPI_CMD}"
for CMD in ${COMMANDS}; do
    which -s "${CMD}" 2>&1 >/dev/null || ERRORS=1
done


USAGE=$( cat << EOM
Usage: `basename ${0}` [-h] [-v]
           -c  Output Cacti data only
           -h  Help
           -v  Turn on debugging output
EOM
)

#
# Get data samples and calculate growth
#
if [ ${ERRORS} -eq 0 ]; then
    # Setup two time windows to extract samples from (we'll fetch the last value from each window).
    WINDOW1_A="$(( ${MOST_RECENT_SAMPLE} - ${GROWTH_PERIOD} - ${SAMPLE_WINDOW_SIZE} ))"
    WINDOW1_B="$(( ${MOST_RECENT_SAMPLE} - ${GROWTH_PERIOD} ))"
    WINDOW2_A="$(( ${MOST_RECENT_SAMPLE} - ${SAMPLE_WINDOW_SIZE} ))"
    WINDOW2_B="${MOST_RECENT_SAMPLE}"

    #
    # Sample 1: 24 hours ago
    #
    SAMPLE1=`eval "${KPI} --start=${WINDOW1_A} --end=${WINDOW1_B}" 2>/dev/null` || ERRORS=1
    SAMPLE1=`echo ${SAMPLE1} | awk '{print $2}' 2>/dev/null` || ERRORS=1

    #
    # Sample 2: now (or, the most recent _and_ reliable sample)
    #
    SAMPLE2=`eval "${KPI} --start=${WINDOW2_A} --end=${WINDOW2_B}" 2>/dev/null` || ERRORS=1
    SAMPLE2=`echo ${SAMPLE2} | awk '{print $2}' 2>/dev/null` || ERRORS=1

    #
    # Calculate LUN growth
    #
    DELTA=`echo "${SAMPLE2} - ${SAMPLE1}" | bc 2>/dev/null` || ERRORS=1
fi

#
# Output results
#
if [ ${CACTI_OUTPUT} ]; then
    if [ ${ERRORS} -eq 0 ]; then
        EXIT_CODE=${STATE_OK}
        echo "kbytes_day:${DELTA}"
    fi    
else
    #
    # Nagios output
    #
    if [ ${ERRORS} -eq 0 ]; then
        if [ `echo "${DELTA} < 0" | bc 2>/dev/null` -eq 1 ]; then
            ABS_DELTA=`echo "${DELTA} * -1" | bc 2>/dev/null`
        else
            ABS_DELTA=${DELTA}
        fi
        if [ `echo "${ABS_DELTA} >= ${NAGIOS_CRITICAL}" | bc 2>/dev/null` -eq 1 ]; then
            EXIT_CODE=${STATE_CRIT};
        else
            if [ `echo "${ABS_DELTA} >= ${NAGIOS_WARNING}" | bc 2>/dev/null` -eq 1 ]; then
                EXIT_CODE=${STATE_WARN}
            else
                EXIT_CODE=${STATE_OK}
            fi
        fi
        INFO="Corpus master DB LUN (${LUN_DEVICE}) growth rate: ${DELTA} kbytes/day"
    fi
    case ${EXIT_CODE} in
        ${STATE_OK}   ) echo "OK - ${INFO}";;
        ${STATE_WARN} ) echo "WARNING - ${INFO}";;
        ${STATE_CRIT} ) echo "CRITICAL - ${INFO}";;
        ${STATE_UNKN} ) echo "UNKNOWN - ${INFO}";;
        *             ) echo "UNKNOWN - ${INFO}";;
    esac
fi

exit ${EXIT_CODE}
