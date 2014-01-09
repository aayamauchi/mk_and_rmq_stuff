#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

HOST=$1
DB=$2
USER=$3
PASS=$4

SQL="SELECT atlas_state.name AS st, atlas_bundlestate.name AS bu, atlas_extendedstate.name AS ex
FROM atlas_instance, atlas_server, atlas_cluster, atlas_state, 
  atlas_bundle, atlas_bundlestate, atlas_extendedstate
WHERE atlas_instance.external_name='${HOST}'
AND atlas_instance.server_id=atlas_server.id
AND atlas_server.state_id=atlas_state.id
AND atlas_server.extended_state_id=atlas_extendedstate.id
AND atlas_instance.cluster_id=atlas_cluster.id
AND atlas_cluster.bundle_id=atlas_bundle.id
AND atlas_bundle.state_id=atlas_bundlestate.id"

OUT=`echo "${SQL}" | mysql --batch --skip-column-names -u ${USER} -p${PASS} -h ${DB} atlas 2>&1`
if [ $? -ne 0 ]
then
    echo "We appear to be experiencing difficulties acquiring provisioning status."
    printf "%b" "${OUT}"
    exit 3
else
    STATE=`echo ${OUT} | cut -d\  -f1`
    BUNDL=`echo ${OUT} | cut -d\  -f2`
    EXTEN=`echo ${OUT} | cut -d\  -f3`
    EXIT=0
    echo -n Device state is \'${STATE}\' and Bundle is \'${BUNDL}\'
    if [ "${EXTEN}" != "DEFAULT" ]
    then
        echo , extended state is \'${EXTEN}\'
    else
        echo
    fi
    case ${STATE} in
        NEW)
            echo ${STATE} is an unexpected pre-allocation state.
            ;;
        UNASSIGNED)
            echo ${STATE} is an unexpected pre-allocation state.
            ;;
        ASSIGNED)
            ;;
        RMA)
            echo ${STATE} device to be recycled, notifications disabled.
            EXIT=2
            ;;
        RESERVED)
            echo ${STATE} is an unhandled state.
            EXIT=3
            ;;
        DEAD)
            echo ${STATE} device, notifications disabled.
            EXIT=2
            ;;
        *)
            echo ${STATE} is an unhandled state.
            EXIT=3
            ;;
    esac
    case ${BUNDL} in
        UNALLOCATED)
            echo ${BUNDL} is an unexpected pre-allocation state.
            ;;
        ALLOCATED)
            echo ${BUNDL} is an unexpected pre-provisioned state.
            ;;
        ALLOCATION_VERIFIED)
            echo ${BUNDL} is an unexpected pre-provisioned state.
            ;;
        PROVISIONED)
            ;;
        REALLOCATE)
            ;;
        REALLOCATED)
            ;;
        *)
            echo ${BUNDL} is an unrecognized state.
            EXIT=3
            ;;
    esac
        



fi
exit ${EXIT}
