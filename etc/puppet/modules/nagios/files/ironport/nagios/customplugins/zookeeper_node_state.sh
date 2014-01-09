#!/usr/local/bin/bash
#==============================================================================
# zookeeper_node_state.sh
#
# Performs two different checks:
#    When called with -c, checks if the number of zookepper connected nodes
#    for the given product equals the number we have configured in ASDB and
#    that they all match by name.
#
#    Without the -c option, checks that we have one active node that is also
#    a validly configured node in ASDB, matched by name.
#
# 2013-03-12 jramache
#==============================================================================
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"

ASDB="asdb.ironport.com"
ASDB_TIMEOUT=15          # asdb connection timeout, in seconds
CACHE_EXPIRE=3600        # max age of asdb cache, in seconds
NODE_TIMEOUT=15          # uridbgen node connection timeout, in seconds
CHECK_ACTIVE=1           # to check active nodes or not

USAGE=$( cat << EOM
Usage: `basename ${0}` -H hostname -p port -a product-env-purpose [-c]
           -H  Host
           -p  Port
           -a  ASDB specification (product-env-purpose)
           -c  Check number of connected nodes in the cluster
EOM
)

OPTIONS=
while getopts ":H:p:a:c" OPTIONS
do
    case ${OPTIONS} in
        H ) HOST="${OPTARG}";;
        p ) PORT="${OPTARG}";;
        a ) PEP="${OPTARG}";;
        c ) CHECK_ACTIVE=0;;
        * ) echo "${USAGE}"
            exit 3;;
    esac
done
if [ "${HOST}" = "" ]; then
    echo "UNKNOWN - Missing host name"
    exit 3
fi
if [ "${PORT}" = "" ]; then
    echo "UNKNOWN - Missing port number"
    exit 3
fi
if [ "${PEP}" = "" ]; then
    echo "UNKNOWN - Missing ASDB specification (product-env-purpose)"
    exit 3
fi
PRODUCT="`echo ${PEP} | cut -d '-' -f 1 2>/dev/null`"
ENVIRONMENT="`echo ${PEP} | cut -d '-' -f 2 2>/dev/null`"
PURPOSE="`echo ${PEP} | cut -d '-' -f 3 2>/dev/null`"
if [ "${PRODUCT}" = "" -o "${ENVIRONMENT}" = "" -o "${PURPOSE}" = "" ]; then
    echo "UNKNOWN - Invalid ASDB specification (product=${PRODUCT}, env=${ENVIRONMENT}, purpose=${PURPOSE})"
    exit 3
fi

ASDB_CACHE="/tmp/cache-${PRODUCT}-nodes-${HOST}"
if [ -L "${ASDB_CACHE}" ]; then
    echo "UNKNOWN - Security issue: ASDB cache file is a link: ${ASDB_CACHE}"
    exit 3
fi

# BSD and Linux isms
if `uname -s | grep Linux 1>/dev/null 2>/dev/null`; then
   MTIME_STAT_CMD='stat -c"%Y"'
else
   MTIME_STAT_CMD='stat -f%m'
fi

if [ ${CHECK_ACTIVE} -eq 1 ]; then
    NODES=`wget --timeout=${NODE_TIMEOUT} -q -O - "http://${HOST}:${PORT}/nodes_connected?service=active" 2>/dev/null`
    if [ ${?} -ne 0 ]; then
        echo "CRITICAL - Error retrieving active node list from ${HOST}"
        exit 2
    fi
else
    NODES=`wget --timeout=${NODE_TIMEOUT} -q -O - "http://${HOST}:${PORT}/nodes_connected" 2>/dev/null`
    if [ ${?} -ne 0 ]; then
        echo "CRITICAL - Error retrieving connected node list from ${HOST}"
        exit 2
    fi
fi

#------------------------------------------------------------------------------
# BEGIN: Obtain the list of configured nodes from asdb cache or asdb
#------------------------------------------------------------------------------
C_NODES_CONFIGURED=""
REFRESH_CACHE=1
CACHE_ERRORS=0
# Look in the cache first
if [ -r "${ASDB_CACHE}" ]; then
    T_NOW=`date +%s`
    T_CACHE=`${MTIME_STAT_CMD} "${ASDB_CACHE}" 2>/dev/null | bc`
    if [ "${T_CACHE}" == "" ]; then
        T_CACHE=0
    fi
    T_AGE=$(( ${T_NOW} - ${T_CACHE} ))
    if [ ${T_AGE} -lt ${CACHE_EXPIRE} ]; then
        REFRESH_CACHE=0
        C_NODES_CONFIGURED=`cat "${ASDB_CACHE}"`
    fi
else
    CACHE_ERRORS=1
fi

NODES_CONFIGURED=""
if [ ${REFRESH_CACHE} -eq 1 -o ${CACHE_ERRORS} -eq 1 ]; then
    ASDB_ERRORS=0
    NODES_CONFIGURED=`wget --timeout=${ASDB_TIMEOUT} -q -O - "http://asdb.ironport.com/servers/list/?product__name=${PRODUCT}&purpose__name=${PURPOSE}&environment__name=${ENVIRONMENT}" 2>/dev/null`
    if [ ${?} -ne 0 ]; then
        ASDB_ERRORS=1
    else
        NODES_CONFIGURED=`echo "${NODES_CONFIGURED}" | awk 'BEGIN {RS=" "} { if (length(\$0) > 0) print \$0}' 2>/dev/null`
    fi
    if [ ${ASDB_ERRORS} -eq 0 ]; then
        # Got reasonable response from ASDB, so refresh cache
        ( cat /dev/null > "${ASDB_CACHE}" ) >/dev/null 2>&1
        if [ ${?} -ne 0 ]; then
            echo "UNKNOWN - Unable to refresh local asdb cache file: ${ASDB_CACHE}"
            exit 3
        else
            echo "${NODES_CONFIGURED}" > "${ASDB_CACHE}"
        fi
    else
        # Errors with ASDB, so try to continue with possibly stale cache data
        if [ ${CACHE_ERRORS} -eq 0 ]; then
            NODES_CONFIGURED=${C_NODES_CONFIGURED}
        else
            # There were cache errors too, so we must abort
            echo "UNKNOWN - Unable to determine number of configured nodes (bad cache and invalid response from asdb)"
            exit 3
        fi
    fi
else
    # We already have valid data from the cache, so keep it
    NODES_CONFIGURED=${C_NODES_CONFIGURED}
fi
#------------------------------------------------------------------------------
# END: Obtain the list of configured nodes from asdb cache or asdb
#------------------------------------------------------------------------------

N_CONFIGURED_NODES=`echo "${NODES_CONFIGURED}" | wc -l | bc`
N_NODES=`echo "${NODES}" | wc -l | bc`

# Check for correct node count
if [ ${CHECK_ACTIVE} -eq 1 ]; then
    if [ ${N_NODES} -lt 1 ]; then
        echo "CRITICAL - No active nodes in service"
        exit 2
    elif [ ${N_NODES} -gt 1 ]; then
        echo "CRITICAL - More than one active node in service"
        exit 2
    fi
else
    if [ ${N_CONFIGURED_NODES} -ne ${N_NODES} ]; then
        echo "CRITICAL - Number of connected nodes (${N_NODES}) not equal to number of configured nodes (${N_CONFIGURED_NODES})"
        exit 2
    fi
fi

# Compare active/connected nodes with configured nodes, by name
ACTIVE_NODE_MATCH=0
ALL_NODES_MATCH=1
IFS="
"
for N in ${NODES}
do
    NODE_HOST=`echo ${N} | awk -F: '{print $1}'`
    NODE_MATCH=0
    for CONFIGURED_HOST in ${NODES_CONFIGURED}
    do
         if [ "${NODE_HOST}" = "${CONFIGURED_HOST}" ]; then
             if [ ${CHECK_ACTIVE} -eq 1 ]; then
                 ACTIVE_NODE_MATCH=1
             fi
             NODE_MATCH=1
             break
         fi

    done
    if [ ${NODE_MATCH} -eq 0 ]; then
        ALL_NODES_MATCH=0
    fi
done

if [ ${ALL_NODES_MATCH} -eq 1 ]; then
    # We have the correct number of active/connected nodes, and they are configured in asdb
    if [ ${CHECK_ACTIVE} -eq 1 ]; then
        echo "OK - Active node: ${NODES}"
    else
        echo "OK - ${N_NODES} connected nodes match ${N_CONFIGURED_NODES} configured nodes"
    fi
    exit 0
elif [ ${ACTIVE_NODE_MATCH} -eq 1 ]; then
    echo "OK - Active node: ${NODES}"
    exit 0
else
    # We have the correct number of active/connected nodes, but they don't match up with configured hosts in asdb
    if [ ${CHECK_ACTIVE} -eq 1 ]; then
        echo "CRITICAL - Active node is not a configured node: ${NODES}"
    else
        echo "CRITICAL - Connected node host names do not match configured nodes"
    fi
    exit 2
fi
