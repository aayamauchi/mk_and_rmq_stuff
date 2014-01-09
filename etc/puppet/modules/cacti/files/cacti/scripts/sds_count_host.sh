#!/usr/local/bin/bash
#==============================================================================
# Simple and crude wrapper for check_sds_counts.py to extract desired counters
# for a specific sds app host rather than all hosts.
#==============================================================================
DB_HOST="prod-sds-db-m1.vega.ironport.com"
DB_USER="nagios"
DB_PASS="thaxu1T"
DB_NAME="sds_vector"
HOST="${1}"
SDS_COUNTER_SCRIPT="/usr/share/cacti/scripts/check_sds_counts.py"

if [ ! -x "${SDS_COUNTER_SCRIPT}" ]; then
    echo "Unable to find executable script: ${SDS_COUNTER_SCRIPT}"
    exit 2
fi

OUTPUT=""
COUNTERS="sbrs.response_time_microseconds memcache.hit_response_time_microseconds memcache.miss_response_time_microseconds sds.total_bad_api_req"
for C in ${COUNTERS}
do
    VALUE=`${SDS_COUNTER_SCRIPT} -c ${DB_HOST} ${DB_USER} ${DB_PASS} ${DB_NAME} check_value ${C} | awk 'BEGIN {RS=" ";} {print $1}' | grep -- ${HOST} | awk -F':' '{print $2}'`
    case ${C} in
        "sbrs.response_time_microseconds")          NAME="sbrsrtm";;
        "sds.total_bad_api_req")					NAME="sdstotbadapireq";;
        "memcache.hit_response_time_microseconds")  NAME="memcachehrtm";;
        "memcache.miss_response_time_microseconds") NAME="memcachemrtm";;
        *) echo "invalid counter name encountered"; exit 2;;
    esac
    OUTPUT="${NAME}:${VALUE} ${OUTPUT}"
done
echo "${OUTPUT}"