#!/bin/sh
#==============================================================================
# disk_growth.sh
#
# Monitor growth rate of a mount point for given host.
# Data samples are retrieved from rrd via disk_capacity.py.
#
# Return codes and their meaning:
#         0 (ok)
#         1 (warning)
#         2 (critical)
#         3 (unknown)
#
# Output:
#     Nagios (one of these):
#         OK - <mount point> growth rate: X
#         WARNING - <mount point> growth rate: X
#         CRITICAL - <mount point> growth rate: X
#         UNKNOWN - Unable to determine <mount point> growth rate
#     Cacti (-g):
#         gbytes_day:N  (where N is the amount of growth in GBytes)
#
# NOTE: Set ERRORS=1 (or non-zero) appropriately to exit in a predictable way.
#
# 2010-03-15 jramache, created for corpus master lun
# 2010-09-04 jramache, generalized for any host/mount, also now using
#                      disk_capacity.py to gather data
#==============================================================================
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/share/cacti/scripts"

CACTI_OUTPUT=
NAGIOS_WARNING=
NAGIOS_CRITICAL=

STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
ERRORS=0

USAGE=$( cat << EOM
Usage: `basename ${0}` [-s hostname -m mount] [[-c gbytes -w gbytes] | -g] [-h] [-v]
           -c  Nagios critical threshold in gbytes (required unless -g specified)
           -w  Nagios warning threshold in gbytes (required unless -g specified)
           -s  System (hostname)
           -m  Mount point
           -g  Output Cacti value only
           -h  Help
           -v  Turn on debugging output
EOM
)

OPTIONS=
while getopts ":c:w:s:m:ghv" OPTIONS
do
    case ${OPTIONS} in
        c ) NAGIOS_CRITICAL="${OPTARG}";;
        w ) NAGIOS_WARNING="${OPTARG}";;
        s ) HOSTNAME="${OPTARG}";;
        m ) MOUNTPOINT="${OPTARG}";;
        g ) CACTI_OUTPUT=1;;
        h ) echo "${USAGE}"
            exit ${EXIT_CODE};;
        v ) VERBOSE=1;;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE};;
    esac
done

#echo "Critical threshold: [${NAGIOS_CRITICAL}]"
#echo "Warning threshold:  [${NAGIOS_WARNING}]"
#echo "Verbose:            [${VERBOSE}]"
#echo "Cacti output:       [${CACTI_OUTPUT}]"

if [ ${VERBOSE} ]; then
    set -x
fi

# command check
COMMANDS="awk bc php tr ${KPI_CMD}"
for CMD in ${COMMANDS}; do
    which "${CMD}" 2>&1 >/dev/null || ERRORS=1
done

if [ -z "${CACTI_OUTPUT}" -a -z "${NAGIOS_WARNING}" -a -z "${NAGIOS_CRITICAL}" ]; then
   echo "${USAGE}"
   exit ${EXIT_CODE}
fi

if [ ! -z "${NAGIOS_WARNING}" -a ! -z "${NAGIOS_CRITICAL}" ]; then
   if [ `echo "${NAGIOS_CRITICAL} <= ${NAGIOS_WARNING}" | bc 2>/dev/null` -eq 1 ]; then
      echo "`basename ${0}`: error: critical threshold must be greater than warning threshold"
      exit ${EXIT_CODE}
   fi
fi

KPI_CMD="disk_capacity.py"
KPI="${KPI_CMD} --host=${HOSTNAME} --mount=${MOUNTPOINT}"

INFO="Unable to determine growth rate for ${MOUNTPOINT}"

#
# Get data samples and calculate growth
#
if [ ${ERRORS} -eq 0 ]; then
    #
    # Obtain last 24 hour disk usage
    #
    # DELTA=`eval "${KPI}" 2>/dev/null | awk -F'	' '{print $10}'`
    DELTA=`eval "${KPI}" 2>/dev/null | sed "s/'/\"/g" | php -r '$A = json_decode(file_get_contents("php://stdin"), TRUE); print $A[0]["last_24h_usage"] . "\n";' 2>/dev/null`
    if [ -z "${DELTA}" ]; then
       ERRORS=1
    fi
    # Strip out any commas in the result
    DELTA=`echo ${DELTA} | sed 's/,//g'`
fi

#
# Create and return output
#
if [ ${CACTI_OUTPUT} ]; then
    if [ ${ERRORS} -eq 0 ]; then
        EXIT_CODE=${STATE_OK}
        echo "gbytes_day:${DELTA}"
    else
        echo "gbytes_day:NaN"
    fi    
else
    #
    # Nagios output
    #
    if [ ${ERRORS} -eq 0 ]; then
        if [ `echo ${DELTA} | tr [:upper:] [:lower:]` = "nan" ]; then
            ERRORS=1
            INFO="Growth rate for ${MOUNTPOINT} is NaN"
        fi
    fi
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
        INFO="Growth rate for ${MOUNTPOINT} is ${DELTA} gbytes/day"
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
