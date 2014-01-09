#!/usr/local/bin/bash
#==============================================================================
# sds_metascandb_mtime.sh
#
# sds_metascandb_mtime.sh hostname directory warning critical
#
# Rudimentary check on the mtime of the latest metascan db files for sds.
#
# A few really important things to know about this script:
#    * Uses ssh to obtain file info remotely.
#    * Exists because check_remote_file.py does not allow for setting the
#      bash extglob option. This option is helpful to limit searches to
#      integer based filenames.
#
# 2012-04-02 jramache
#==============================================================================
STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Unable to determine latest metascan db mtime (perhaps filename or mtime are not integers?)"

HOSTNAME="${1}"
DIRECTORY="${2}"
WARNING=`echo ${3} | bc`
CRITICAL=`echo ${4} | bc`

# Retrieve latest [integer based] file name and mtime, crammed together in one result.
# Uses Linux stat variant.
RESULT=`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOSTNAME} "shopt -s extglob; L=\\\`ls -tr ${DIRECTORY}/+([0-9]) | tail -1\\\`; echo -n \"file:\\\${L} mtime:\"; stat -c'%Y' \\\${L}" 2>/dev/null`

# Separate the file name and mtime (and try to convert to integers, since filename is required to be an integer)
FILE=`echo "${RESULT}" | awk '{print $1}' 2>/dev/null | awk -F':' '{print $2}' 2>/dev/null | xargs -n1 basename 2>/dev/null | bc 2>/dev/null`
MTIME=`echo "${RESULT}" | awk '{print $2}' 2>/dev/null | awk -F':' '{print $2}' 2>/dev/null | bc 2>/dev/null`

# Ensure file and mtime are not empty and both are integers, then check mtime
if [ "${FILE}" != "" -a "${MTIME}" != "" ]; then
    if [ ${FILE} -eq ${FILE} -a ${MTIME} -eq ${MTIME} ] 2>/dev/null; then
        NOW=`date +%s`
        AGE=$(( ${NOW} - ${MTIME} ))
        if [ ${AGE} -ge ${CRITICAL} ]; then
            EXIT_CODE=${STATE_CRIT}
            INFO="${DIRECTORY}/${FILE} last updated ${AGE} seconds ago, Critical threshold: ${CRITICAL}"
        elif [ ${AGE} -ge ${WARNING} ]; then
            EXIT_CODE=${STATE_WARN}
            INFO="${DIRECTORY}/${FILE} last updated ${AGE} seconds ago, Warning threshold: ${WARNING}"
        else
            EXIT_CODE=${STATE_OK}
            INFO="${DIRECTORY}/${FILE} last updated ${AGE} seconds ago"
        fi
    fi
fi

# Finish up
case ${EXIT_CODE} in
    ${STATE_OK}   ) echo "OK - ${INFO}";;
    ${STATE_WARN} ) echo "WARNING - ${INFO}";;
    ${STATE_CRIT} ) echo "CRITICAL - ${INFO}";;
    ${STATE_UNKN} ) echo "UNKNOWN - ${INFO}";;
    *             ) echo "UNKNOWN - ${INFO}";;
esac

exit ${EXIT_CODE}
