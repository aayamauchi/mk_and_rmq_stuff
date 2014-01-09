#!/usr/local/bin/bash

LAG=`echo "SELECT (unix_timestamp() - max(mtime)) / ((unix_timestamp() - min(mtime)) / \
count(distinct(current_file_url))) lag FROM job_control WHERE rule_id IN (SELECT rule_id \
FROM rule_source WHERE disabled=0)" | mysql -N -u $1 -p$2 -h $3 controller`


if [[ "${LAG}" != "" ]] && [[ "${LAG}" != "NULL" ]]
then
    if [[ `echo "${LAG} > 5" | bc` -gt 0 ]]
    then
        OUT="${LAG} multiples lag detected!"
        EXIT=2
    elif [[ `echo "${LAG} > 3" | bc` -gt 0 ]]
    then
        OUT="${LAG} multiples lag detected."
        EXIT=1
    else
        OUT="${LAG} multiples lag."
    fi
elif [ "${LAG}" == "" ]
then
    OUT="Error querying database."
    EXIT=3
elif [ "${LAG}" == "" ]
then
    OUT="No data returned from db."
    EXIT=3
fi
echo $OUT
exit $EXIT
