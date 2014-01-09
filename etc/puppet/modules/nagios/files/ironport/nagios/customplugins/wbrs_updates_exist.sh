#!/usr/local/bin/bash
#==============================================================================
# wbrs_updates_exist.sh
#
# Usage: wbrs_updates_exist.sh warn crit host directory[ directory...]
#
# Verifies that at least warn/crit updates exist in each of the wbrs
# directories provided on the command line, along with corresponding
# crypto and md5 files. One ssh call is made to the remote host.
#
# 2012-08-07 jramache
#==============================================================================
HOSTNAME="${1}"
WARNING="${2}"
CRITICAL="${3}"
shift
shift
shift
DIRECTORIES="${*}"

if [ "${HOSTNAME}" == "" ]; then
    echo "UNKNOWN - hostname not provided"
    exit 3
fi
if [ "${WARNING}" != "" -a "${CRITICAL}" != "" ]; then
    if [ ${WARNING} -eq ${WARNING} ] 2>/dev/null; then
        if [ ${CRITICAL} -eq ${CRITICAL} ] 2>/dev/null; then
            if [ `echo "${CRITICAL} > ${WARNING}" | bc 2>/dev/null` -eq 1 ]; then
                echo "UNKNOWN - critical threshold must be less than or equal to warning threshold"
                exit 3
            fi
        else
            echo "UNKNOWN - critical value is not a number"
            exit 3
        fi
    else
        echo "UNKNOWN - warning value is not a number"
        exit 3
    fi
else
    echo "UNKNOWN - thresholds not provided"
    exit 3
fi
if [ "${DIRECTORIES}" == "" ]; then
    echo "UNKNOWN - directory not provided"
    exit 3
fi

EXIT_CODE=0
INFO=""

# Retrieve a bulk dump of directory listings: assumes small number of entries in each dir
RESULTS=`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOSTNAME} "ls ${DIRECTORIES} 2>/dev/null"`

DIRENTRIES=""
GetDirEntries() {
    # Return a list of all files for given directory
    DIR="${1}"
    DIRENTRIES=""
    IN_DIR=0
    PROCESSED=0
    for L in ${RESULTS}
    do
        if [ ${PROCESSED} -eq 1 ]; then
            return
        elif echo "${L}" | grep -q "^${DIR}:\$" ; then
            IN_DIR=1
        elif echo "${L}" | grep -q '^/.*:' ; then
            if [ ${IN_DIR} -eq 1 ]; then
                PROCESSED=1
                IN_DIR=0
            fi
        elif echo "${L}" | grep -q '^$' ; then
            if [ ${IN_DIR} -eq 1 ]; then
                PROCESSED=1
                IN_DIR=0
            fi
        elif [ ${IN_DIR} -eq 1 ]; then
            if [ "${DIRENTRIES}" == "" ]; then
                DIRENTRIES="${L}"
            else
                DIRENTRIES="${DIRENTRIES}
${L}"
            fi
        fi
    done
}

# Check every directory
for DIRECTORY in ${DIRECTORIES}
do
    IFS="
"
    GetDirEntries "${DIRECTORY}"
    FILES=""
    N_FILES=0
    N_VALID_FILES=0
    for E in ${DIRENTRIES}
    do
        echo "${E}" | egrep "(\.md5|\.crypto)" >/dev/null 2>&1
        if [ ${?} -ne 0 ]; then
            N_FILES=$(( ${N_FILES} + 1 ))
            if [ "${FILES}" == "" ]; then
                FILES="${E}"
            else
                FILES="${E}
${FILES}"
            fi
        fi
    done
    if [ ${N_FILES} -le 0 ]; then
        INFO="${INFO}
No updates in ${DIRECTORY}"
        EXIT_CODE=2
    else
        for F in ${FILES}
        do
            CRYPTO=0
            MD5=0
            for E in ${DIRENTRIES}
            do
                if [ "${E}" == "${F}.crypto" ]; then
                    CRYPTO=1
                elif [ "${E}" == "${F}.md5" ]; then
                    MD5=1
                fi
            done
            if [ ${CRYPTO} -eq 1 -a ${MD5} -eq 1 ]; then
                N_VALID_FILES=$(( ${N_VALID_FILES} + 1 ))
            fi
        done
        UPDATE_STR="update"
        if [ ${N_VALID_FILES} -ne 1 ]; then
            UPDATE_STR="updates"
        fi
        if [ ${N_VALID_FILES} -le ${CRITICAL} ]; then
            INFO="${INFO}
CRITICAL - Only ${N_VALID_FILES} ${UPDATE_STR} in ${DIRECTORY}"
            EXIT_CODE=2
        elif [ ${N_VALID_FILES} -le ${WARNING} ]; then
            INFO="${INFO}
WARNING - Only ${N_VALID_FILES} ${UPDATE_STR} in ${DIRECTORY}"
            if [ ${EXIT_CODE} -le 1 ]; then
                EXIT_CODE=1
            fi
        fi
    fi
done

if [ ${EXIT_CODE} -eq 0 ]; then
    echo "OK - Updates exist in all WBRS directories"
    exit 0
else
    N=`echo "${INFO}" | wc -l`
    N=$(( ${N} - 1 ))
    INFO=`echo "${INFO}" | tail -${N}`
    if [ ${N} -gt 1 ]; then
        echo "Multiple issues (see remaining output)"
    fi
    echo "${INFO}"
    exit ${EXIT_CODE}
fi
