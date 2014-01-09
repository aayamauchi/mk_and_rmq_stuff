#!/usr/local/bin/bash
#
# $0 user password xbrs-app-node crit env

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/nagios/libexec:/usr/local/ironport/nagios/customplugins

EXIT=0
OK=''
WARN=''
CRIT=''
UNKN=''
IP=$3

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

is_ip(){

    input=${IP}
    octet1=$(echo $input | cut -d "." -f1)
    octet2=$(echo $input | cut -d "." -f2)
    octet3=$(echo $input | cut -d "." -f3)
    octet4=$(echo $input | cut -d "." -f4)
    stat=0

if [[ $input =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && [ $octet1 -le 255 ] && [ $octet2 -le 255 ] && [ $octet3 -le 255 ] && [ $octet4 -le 255 ];
  then
    	domain=`host ${IP} | awk {' print $5 '} | awk -F. {' print $1"."$2 '}`
	stat=1
  else
	stat=0
	domain=${IP}
fi

return $stat
}

is_ip $3

HOST="$5-xbrs-db-m1.vega.ironport.com"  # All masters are in vega.

OUT=`/usr/local/ironport/nagios/customplugins/check_mysql_data.py --user $1 --password $2 --host ${HOST} --db controller -c $4 --invers \
--query "SELECT count(*) * 100 / ((SELECT count(*) FROM job_control WHERE primary_node IS NOT NULL) / (SELECT count(distinct(substring_index(primary_node, ':', 1))) FROM job_control WHERE primary_node IS NOT NULL)) its_pct FROM job_control WHERE primary_node LIKE '${domain}%'"`
RET=$?
if [[ ${RET} -eq 2 ]]
then
    CRIT="XBRS App not working hard enough! ${OUT}"
    code 2
elif [[ ${RET} -eq 0 ]]
then
    OK="XBRS App working sufficiently hard. ${OUT}"
else
    UNKN="XBRS App load collection error.\n"
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







