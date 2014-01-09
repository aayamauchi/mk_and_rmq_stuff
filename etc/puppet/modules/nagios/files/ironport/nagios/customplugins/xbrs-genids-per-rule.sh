#!/usr/local/bin/bash
#
# $0 user password host

PATH=/bin:/usr/bin:/usr/local/bin

LAG=`echo "SELECT (unix_timestamp() - max(mtime)) / ((max(mtime) - min(mtime)) / 
count(distinct(current_file_url))) lag FROM (SELECT * FROM job_control WHERE rule_id=(SELECT 
rule_id FROM rule_source WHERE rule_mnemonic='$4')) a" | \
mysql -N -u $1 -p$2 -h $3 controller`

if [[ "${LAG}" != "" ]] && [[ "${LAG}" != "NULL" ]]
then
    if [[ `echo "${LAG} > 2" | bc` -gt 0 ]]
    then
        echo "${LAG} minutes lag detected in in XBRS for Rule: $4"
        if [[ `echo "${LAG} > 4" | bc` -gt 0 ]]
        then
            exit 2
        else
            exit 1
        fi
    fi
elif [ "${LAG}" == "" ]
then
    echo "Error querying database."
    exit 3
elif [ "${LAG}" == "" ]
then
    echo "No data returned from db."
    exit 3
fi

echo "${LAG} minutes lag in XBRS for Rule: $4"
exit 0
