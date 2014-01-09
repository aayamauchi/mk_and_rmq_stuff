#!/usr/local/bin/bash
#
# $0 user password host rule resetcrit resetwarn undonecrit undonewarn purgecrit purgewarn

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/nagios/libexec:/usr/local/ironport/nagios/customplugins

EXIT=0
OK=''
WARN=''
CRIT=''
UNKN=''

function code {
    c=$1
    if [[ ${c} -eq 2 ]]
    then
        EXIT=2
    elif [[ ${c} -eq 1 ]] && [[ ${EXIT} -ne 2 ]]
    then
        EXIT=1
    elif [[ ${c} -ne 0 ]] && [[ ${EXIT} -eq 0 ]]
    then
        EXIT=3
    fi
}

#LAG=`echo "SELECT (unix_timestamp() - max(mtime)) / ((unix_timestamp() - min(mtime)) / 
#count(distinct(current_file_url))) lag FROM (SELECT * FROM job_control WHERE rule_id=(SELECT 
#rule_id FROM rule_source WHERE disabled=0 AND rule_mnemonic='$4')) a" | \
#mysql -N -u $1 -p$2 -h $3 controller`

#if [[ "${LAG}" != "" ]] && [[ "${LAG}" != "NULL" ]]
#then
#    if [[ `echo "${LAG} > 5" | bc` -gt 0 ]]
#    then
#        CRIT="${LAG} minutes lag detected!\n"
#        code 2
#    elif [[ `echo "${LAG} > 3" | bc` -gt 0 ]]
#    then
#        WARN="${LAG} minutes lag detected.\n"
#        code 1
#    else
#        OK="${LAG} minutes lag.\n"
#    fi
#elif [ "${LAG}" == "" ]
#then
#    UNKN="Error querying database.\n"
#    code 3
#elif [ "${LAG}" == "" ]
#then
#    UNKN="No data returned from db.\n"
#    code 3
#fi


# TOO MANY RESETS
#            "controller!SELECT count(*) FROM job_control WHERE rule_id=(SELECT rule_id FROM " + \
#                    "rule_source WHERE rule_mnemonic='$$') AND update_type='RESET' AND " + \
#                    "(unix_timestamp() - ctime) <= 86400*7!1!1",

OUT=`check_mysql_data.py --user $1 --password $2 --host $3 --db controller -c $5 -w $6 \
--query "SELECT count(*) FROM job_control WHERE rule_id=(SELECT rule_id FROM rule_source WHERE \
disabled=0 AND rule_mnemonic='$4') AND update_type='RESET' AND (unix_timestamp() - ctime) <= 3600"`
RET=$?
RETC=`echo $5 + 1 | bc`
RETW=`echo $6 + 1 | bc`
WOUT=`check_mysql_data.py --user $1 --password $2 --host $3 --db controller -c ${RETC} -w ${RETW} \
--query "SELECT count(*) FROM job_control WHERE rule_id=(SELECT rule_id FROM rule_source WHERE \
disabled=0 AND rule_mnemonic='$4') AND update_type='RESET' AND (unix_timestamp() - ctime) <= 86400*7"`
WRET=$?
if [[ ${RET} -eq 2 ]] && [[ ${WRET} -eq 2 ]]
then
    CRIT="${CRIT}Too many resets!\n"
    CRIT="${CRIT}Last Hour:${OUT}Last Week:${WOUT}\n"
    code 2
elif [[ ${RET} -eq 1 ]] || [[ ${RET} -eq 2 ]]
then
    WARN="${WARN}Too many resets.\n"
    WARN="${WARN}Last Hour:${OUT}\n"
    code 1
elif [[ ${RET} -eq 0 ]]
then
    OK="${OK}Reset threshold OK\n"
else
    UNKN="${UNKN}Reset threshold check error.\n"
    UNKN="${UNKN}${OUT}\n"
    code 3
fi

# UNDONE JOBS
#            "controller!SELECT count(*) FROM job_control WHERE rule_id=(SELECT rule_id FROM " + \
#                    "rule_source WHERE rule_mnemonic='$$') AND row_id > (SELECT row_id FROM " + \
#                    "job_control WHERE gen_id > 0 AND rule_id=(SELECT rule_id FROM " + \
#                    "rule_source WHERE rule_mnemonic='$$') ORDER BY gen_id DESC LIMIT 1)!4!2",

# This used to take a warning threshold on $8.  In order to provide a clean migration, $8 is now
# dead to us.

OUT=`check_mysql_data.py --user $1 --password $2 --host $3 --db controller -c $7 \
--query "SELECT IFNULL((unix_timestamp() - min(ctime)) / (SELECT max(processing_time) FROM job_control),0) o \
FROM job_control WHERE rule_id=(SELECT rule_id FROM rule_source WHERE rule_mnemonic='%4') AND \
row_id > (SELECT row_id FROM job_control WHERE gen_id > 0 AND rule_id=(SELECT rule_id FROM rule_source \
WHERE disabled=0 AND rule_mnemonic='$4') ORDER BY gen_id DESC LIMIT 1)"`
RET=$?
if [[ ${RET} -eq 2 ]]
then
    CRIT="${CRIT}Too many undone jobs!\n"
    CRIT="${CRIT}${OUT}\n"
    code 2
elif [[ ${RET} -eq 1 ]]
then
    WARN="${WARN}Too many undone jobs.\n"
    WARN="${WARN}${OUT}\n"
    code 1
elif [[ ${RET} -eq 0 ]]
then
    OK="${OK}Undone job threshold OK\n"
else
    UNKN="${UNKN}Undone job threshold check error.\n"
    UNKN="${UNKN}${OUT}\n"
    code 3
fi

# PURGE INTERVAL
#            "controller!SELECT (unix_timestamp() - min(a.ctime)) / b.purge_interval
#                    "purge_intervals_over FROM job_control a, rule_source b WHERE a.rule_id=b.rule_id " + \
#                    "AND a.rule_id=(SELECT rule_id FROM rule_source WHERE rule_mnemonic='$$')!3!2"}

OUT=`check_mysql_data.py --user $1 --password $2 --host $3 --db controller -c $9 -w ${10} \
--query "SELECT IF(unix_timestamp() - min(a.ctime) > b.purge_interval, 0, \
(unix_timestamp() - min(a.ctime)) / b.purge_interval) purge_intervals_over \
FROM job_control a, rule_source b WHERE a.rule_id=b.rule_id AND a.rule_id=(SELECT rule_id \
FROM rule_source WHERE disabled=0 AND rule_mnemonic='$4')"`
RET=$?
if [[ ${RET} -eq 2 ]]
then
    CRIT="${CRIT}Purge interval overrun!\n"
    CRIT="${CRIT}${OUT}\n"
    code 2
elif [[ ${RET} -eq 1 ]]
then
    WARN="${WARN}Purge interval overrun.\n"
    WARN="${WARN}${OUT}\n"
    code 1
elif [[ ${RET} -eq 0 ]]
then
    OK="${OK}Purge interval OK\n"
else
    UNKN="${UNKN}Purge interval threshold check error.\n"
    UNKN="${UNKN}${OUT}\n"
    code 3
fi


if [[ ${EXIT} -eq 2 ]]
then
    printf "%b" "XBRS Rule $4 failure.\n${CRIT}${UNKN}${WARN}${OK}"
elif [[ ${EXIT} -eq 3 ]]
then
    printf "%b" "XBRS Rule $4 failure.\n${UNKN}${WARN}${OK}"
elif [[ ${EXIT} -eq 1 ]]
then
    printf "%b" "XBRS Rule $4 warning.\n${WARN}${OK}"
else
    printf "%b" "XBRS Rule $4 OK.\n${OK}"
fi

exit ${EXIT}







