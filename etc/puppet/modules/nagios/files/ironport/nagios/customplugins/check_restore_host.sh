#!/usr/local/bin/bash
#==============================================================================
# check_restore_host.sh
#
# Dispatch ssh-based check to the appropriate db restore server for the given
# slave. Uses slave location and ASDB to determine the correct restore server.
#
# 2011-05-13 jramache
#==============================================================================
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"

ASDB="asdb.ironport.com"
ASDB_CACHE="/tmp/db_restore_hosts.cache"
ASDB_TIMEOUT=15          # asdb connection timeout, in seconds
CACHE_EXPIRE=3600        # max age of asdb cache, in seconds

SLAVE=
LOCATION=
SSHCMD=

# BSD and Linux isms
if `uname -s | grep Linux 1>/dev/null 2>/dev/null`; then
   MTIME_STAT_CMD='stat -c"%Y"'
else
   MTIME_STAT_CMD='stat -f%m'
fi

USAGE=$( cat << EOM
Usage: `basename ${0}` -s sshcmd -H hostname -C command
           -s  SSH command
           -H  Slave hostname
           -C  Check command
EOM
)

OPTIONS=
while getopts ":s:C:H:" OPTIONS
do
    case ${OPTIONS} in
        s ) SSHCMD="${OPTARG}";;
        H ) SLAVE="${OPTARG}";;
        C ) COMMAND="${OPTARG}";;
        * ) echo "${USAGE}"
            exit ${EXIT_CODE};;
    esac
done

if [ "${SSHCMD}" = "" ]; then
    echo "UNKNOWN - Missing SSH command specification"
    exit 3
fi
if [ "${SLAVE}" = "" ]; then
    echo "Empty slave hostname"
    exit 3
fi

LOCATION=`expr "${SLAVE}" : '.*\.\(.*\)\.ironport\.com'`

if [ -L "${ASDB_CACHE}" ]; then
    echo "Security issue: ASDB cache file is a link: ${ASDB_CACHE}"
    exit 3
fi

C_SOMA_RESTORE_HOST=""
C_VEGA_RESTORE_HOST=""
REFRESH_CACHE=1
CACHE_ERRORS=0
# Look for answers in the cache first
if [ -r "${ASDB_CACHE}" ]; then
    T_NOW=`date +%s`
    T_CACHE=`${MTIME_STAT_CMD} "${ASDB_CACHE}" 2>/dev/null | bc`
    if [ "${T_CACHE}" == "" ]; then
        T_CACHE=0
    fi
    T_AGE=$(( ${T_NOW} - ${T_CACHE} ))
    if [ ${T_AGE} -lt ${CACHE_EXPIRE} ]; then
        REFRESH_CACHE=0
    fi
    C_SOMA_RESTORE_HOST=`grep -m1 -i '^soma:' "${ASDB_CACHE}" 2>/dev/null`
    if [ ${?} -ne 0 ]; then
        CACHE_ERRORS=1
    else
        C_SOMA_RESTORE_HOST=`echo "${C_SOMA_RESTORE_HOST}" | awk -F':' '{print $2}' 2>/dev/null`
    fi
    C_VEGA_RESTORE_HOST=`grep -m1 -i '^vega:' "${ASDB_CACHE}" 2>/dev/null`
    if [ ${?} -ne 0 ]; then
        CACHE_ERRORS=1
    else
        C_VEGA_RESTORE_HOST=`echo "${C_VEGA_RESTORE_HOST}" | awk -F':' '{print $2}' 2>/dev/null`
    fi
else
    CACHE_ERRORS=1
fi

SOMA_RESTORE_HOST=""
VEGA_RESTORE_HOST=""
if [ ${REFRESH_CACHE} -eq 1 -o ${CACHE_ERRORS} -eq 1 ]; then
    ASDB_ERRORS=0
    SOMA_RESTORE_HOST=`wget --timeout=${ASDB_TIMEOUT} -q -O - "http://${ASDB}/servers/list/?product__name=ops&purpose__name=restoredbm&environment__name=ops&tags__name=profile-tag-dbrestore-soma" 2>/dev/null`
    if [ ${?} -ne 0 ]; then
        ASDB_ERRORS=1
    else
        SOMA_RESTORE_HOST=`echo "${SOMA_RESTORE_HOST}" | awk '{print $1}' | sed 's/^[[:blank:]]*//g'`
    fi
    VEGA_RESTORE_HOST=`wget --timeout=${ASDB_TIMEOUT} -q -O - "http://${ASDB}/servers/list/?product__name=ops&purpose__name=restoredbm&environment__name=ops&tags__name=profile-tag-dbrestore-vega" 2>/dev/null`
    if [ ${?} -ne 0 ]; then
        ASDB_ERRORS=1
    else
        VEGA_RESTORE_HOST=`echo "${VEGA_RESTORE_HOST}" | awk '{print $1}' | sed 's/^[[:blank:]]*//g'`
    fi
    if [ ${ASDB_ERRORS} -eq 0 ]; then
        # Got reasonable response from ASDB, so refresh cache
        ( cat /dev/null > "${ASDB_CACHE}" ) >/dev/null 2>&1
        if [ ${?} -ne 0 ]; then
            echo "Unable to refresh local asdb cache file: ${ASDB_CACHE}"
            exit 3
        else
            echo "soma:${SOMA_RESTORE_HOST}" >> "${ASDB_CACHE}"
            echo "vega:${VEGA_RESTORE_HOST}" >> "${ASDB_CACHE}"
        fi
    else
        # Errors with ASDB, so try to continue with possibly stale cache data
        if [ ${CACHE_ERRORS} -eq 0 ]; then
            SOMA_RESTORE_HOST="${C_SOMA_RESTORE_HOST}"
            VEGA_RESTORE_HOST="${C_VEGA_RESTORE_HOST}"
        else
            # There were cache errors too, so we must abort
            echo "Unable to determine restore host (bad cache and invalid response from asdb)"
            exit 3
        fi
    fi
else
    # We already have valid data from the cache, so keep it
    SOMA_RESTORE_HOST="${C_SOMA_RESTORE_HOST}"
    VEGA_RESTORE_HOST="${C_VEGA_RESTORE_HOST}"
fi

case ${LOCATION} in
    #    "soma"|"sv2"|"coma"|"nap5" ) RESTORE_HOST="${SOMA_RESTORE_HOST}" ;;
    "vega"                     ) RESTORE_HOST="${VEGA_RESTORE_HOST}" ;;
    *                          ) RESTORE_HOST= ;;
esac

if [ -z ${RESTORE_HOST} ]; then
#    echo "UNKNOWN - Unable to determine restore host"
#    exit 3
    echo "OK - Restore host is temporarily unavailable for checking."
    exit 0
fi

#
# and finally, check on the slave's restore state
#
${SSHCMD} -H ${RESTORE_HOST} -C "${COMMAND} -H ${SLAVE}"
exit ${?}
