#!/usr/local/bin/bash
#
# $0 user password repdbhost crit warn

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


CUT=`echo $3 | cut -f 3 -d\- | cut -f 1 -d.`

HOST=`echo $3 | sed -e "s/${CUT}/db-m1/" -e "s/soma/vega/"` # All masters are in vega.
                                                            # do something smarter, if we eventually
                                                            # have masters elsewhere.


OUT=`check_mysql_data.py --user $1 --password $2 --host ${HOST} --db controller -c $4 -w $5 \
--query "SELECT (select unix_timestamp() - unix_timestamp(max(mtime)) FROM dbwriters_status \
WHERE db_host LIKE '${3}%') - cast((SELECT max(timeout) FROM rule_source) as signed) - \
(SELECT unix_timestamp() - max(ctime) FROM job_control) overdue"`
RET=$?
if [[ ${RET} -eq 2 ]]
then
    CRIT="XBRS RepDB not checking in with master ${HOST}! ${OUT}"
    code 2
elif [[ ${RET} -eq 1 ]]
then
    WARN="XBRS RepDB not checking in with master ${HOST}. ${OUT}"
    WARN="${WARN}${OUT}\n"
    code 1
elif [[ ${RET} -eq 0 ]]
then
    OK="XBRS RepDB last checkin with master ${HOST} ok.  ${OUT}"
else
    UNKN="XBRS RepDB checkin data collection error.\n"
    UNKN="${UNKN}${OUT}\n"
    code 3
fi


if [[ ${EXIT} -eq 2 ]]
then
    printf "%b" "${CRIT}${UNKN}${WARN}${OK}"
elif [[ ${EXIT} -eq 3 ]]
then
    printf "%b" "${UNKN}${WARN}${OK}"
elif [[ ${EXIT} -eq 1 ]]
then
    printf "%b" "${WARN}${OK}"
else
    printf "%b" "${OK}"
fi
echo

exit ${EXIT}







