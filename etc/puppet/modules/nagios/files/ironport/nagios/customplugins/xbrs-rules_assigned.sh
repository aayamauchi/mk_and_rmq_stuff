#!/usr/local/bin/bash
#
# $0 user password host

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

RULES=`echo "SELECT distinct(rule_id) FROM dbwriters_status" |\
mysql -N -u $1 -p$2 -h $3 controller`
RC=`echo ${RULES} | wc -w | sed -e 's/^ *//g'`
ACTIVE=`echo "SELECT distinct(rule_id) FROM rule_source WHERE disabled=0" |\
mysql -N -u $1 -p$2 -h $3 controller`
AC=`echo ${ACTIVE} | wc -w | sed -e 's/^ *//g'`

if [[ ${RC} -ne ${AC} ]]
then
    for rule in ${RULES}
    do
        if [[ "${ACTIVE}" != *"${rule}"* ]]
        then
            CRIT="${CRIT}Rule ${rule} not assigned to DBWriter host!\n"
            code 2
        fi
    done
fi



if [[ ${EXIT} -ne 0 ]]
then
    printf "%b" "${CRIT}${UNKN}${WARN}${OK}"
else
    printf "%b" "${AC} rules in db, all active.\n"
fi

exit ${EXIT}







