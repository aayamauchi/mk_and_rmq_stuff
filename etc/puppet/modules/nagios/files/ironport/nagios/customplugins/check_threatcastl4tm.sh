#!/usr/local/bin/bash
#==============================================================================
# check_threatcastl4tm.sh
#
# Rudimentary check on latest threatcast l4tm file.
#
# A few important things to know about this script:
#    * Uses ssh to obtain file info remotely.
#    * Exists because check_remote_file.py did not handle large directories
#      of files (>4000) accessed via NFS in a timely manner.
#    * Assumes l4tm filenames are unix timestamps, and determines which file
#      is the latest by the filename (rather than a stat on each file).
#      This is what enables this script to work so quickly.
#    * Only cares about a critical threshold.
#    * I know it's ugly and highly specialized for l4tm files, but it works.
#
# Both age and size are optional. If neither are specified, script ensures
# that the latest file exists and is non-zero in size.
#
# 2011-08-15 jramache
# 2012-10-08 jramache, renamed and added age check in addition to size
#==============================================================================
STATE_OK=0
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to determine latest file size (perhaps filename or size are not integers?)"

HOSTNAME=""
DIRECTORY=""
MAX_AGE=0
MIN_SIZE=1

USAGE=$( cat << EOM
Usage: `basename ${0}` -H hostname -d dir -a seconds -s bytes -e exclude
           -H  Host
           -d  Directory
           -a  Created age (in seconds) that latest file must be less than or equal to
           -s  Size (in bytes) that latest file must be greater than or equal to
           -e  Filename patterns to exclude (comma separated with no spaces)
EOM
)

OPTIONS=
while getopts ":H:d:a:s:e:" OPTIONS
do
    case ${OPTIONS} in
        H ) HOSTNAME="${OPTARG}";;
        d ) DIRECTORY="${OPTARG}";;
        a ) MAX_AGE="${OPTARG}";;
        s ) MIN_SIZE="${OPTARG}";;
        e ) EXCLUDE="${OPTARG}";;
        * ) echo "${USAGE}"
            exit 3;;
    esac
done
if [ "${HOSTNAME}" = "" ]; then
    echo "UNKNOWN - Missing host name"
    exit 3
fi
if [ "${DIRECTORY}" = "" ]; then
    echo "UNKNOWN - Missing directory"
    exit 3
fi
MAX_AGE=`echo ${MAX_AGE} | bc`
MIN_SIZE=`echo ${MIN_SIZE} | bc`
EXCLUDE="`echo ${EXCLUDE} | sed 's/,/ /g'`"
EXCLUDE_PATTERNS=""
for E in ${EXCLUDE}
do
    EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS} -a ! -name '*${E}*'"
done

# Retrieve latest file name and size (in bytes), crammed together in one result
RESULT=`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOSTNAME} "L=\\\`find ${DIRECTORY}/ \\( -maxdepth 1 ${EXCLUDE_PATTERNS} \\) 2>/dev/null | awk -F'/' 'BEGIN { l= 0; } { if ( ( 1 * \\\$NF) > l ) l = \\\$NF; } END { print l; }' 2>/dev/null\\\`; echo -n \"file:\\\${L} size:\"; stat -f'%z' ${DIRECTORY}/\\\${L}" 2>/dev/null`

# Separate the file name and size (and try to convert to integers)
FILE=`echo "${RESULT}" | awk '{print $1}' 2>/dev/null | awk -F':' '{print $2}' 2>/dev/null | bc 2>/dev/null`
SIZE=`echo "${RESULT}" | awk '{print $2}' 2>/dev/null | awk -F':' '{print $2}' 2>/dev/null | bc 2>/dev/null`

# Ensure file and size are integers, then perform checks
SIZE_STATUS=0
SIZE_INFO=""
AGE_STATUS=0
AGE_INFO=""
if [ ${FILE} -eq ${FILE} -a ${SIZE} -eq ${SIZE} ] 2>/dev/null; then
    T_NOW=`date +%s`
    T_AGE=$(( ${T_NOW} - ${FILE} ))
    if [ ${MAX_AGE} -ne 0 ]; then
        if [ ${T_AGE} -gt ${MAX_AGE} ]; then
            AGE_STATUS=${STATE_CRIT}
            AGE_INFO="age ${T_AGE} is above threshold (> ${MAX_AGE} seconds)"
        fi
    fi

    if [ ${SIZE} -lt ${MIN_SIZE} ]; then
        SIZE_STATUS=${STATE_CRIT}
        SIZE_INFO="size ${SIZE} is below threshold (< ${MIN_SIZE} bytes)"
    fi

    if [ ${AGE_STATUS} -ne 0 -o ${SIZE_STATUS} -ne 0 ]; then
        EXIT_CODE=${STATE_CRIT}
        INFO="${DIRECTORY}/${FILE}:"
        if [ ${AGE_STATUS} -ne 0 -a ${SIZE_STATUS} -ne 0 ]; then
            INFO="${INFO} ${AGE_INFO}, ${SIZE_INFO}"
        else
            INFO="${INFO} ${AGE_INFO}${SIZE_INFO}"
        fi
    else
        EXIT_CODE=${STATE_OK}
        INFO="${DIRECTORY}/${FILE} is ${SIZE} bytes, created ${T_AGE} seconds ago"
    fi
fi

# Finish up
case ${EXIT_CODE} in
    ${STATE_OK}   ) echo "OK - ${INFO}";;
    ${STATE_CRIT} ) echo "CRITICAL - ${INFO}";;
    ${STATE_UNKN} ) echo "UNKNOWN - ${INFO}";;
    *             ) echo "UNKNOWN - ${INFO}";;
esac

exit ${EXIT_CODE}
