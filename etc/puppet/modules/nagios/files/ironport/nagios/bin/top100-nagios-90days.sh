#!/usr/bin/env bash

#### DESC:
#### Checks Nagios Log files for specified timeline for critical/hard states
#### Per tickets: MONOPS-1100, SYSOPS-29003
####

######### Default Variables #########
DIR="/usr/local/nagios/var/log/"
DIRARCH="/data/nagios-archives/"
DAYS="90"
SHOW="10"
FILE="/tmp/top100.log.tmp"
CHECKHOST="1"
CHECKSERVICE="0"
RUNBOOK="0"
RUNBOOKLOG="/tmp/runbook_audit.csv"
AUDIT_RUNBOOK="/tmp/runbook_audit.tmp"
AUDIT_NORUNBOOK="/tmp/norunbook_audit.tmp"
######## Functions ######

usage()
{
cat << EOF
usage: $0 options

Gather top hosts and services from Nagios logs w/ runbook comparison.
If no args are given script will gather services with down state without runbook comparison for the last 90 days.

OPTIONS:
   -h      Show this message
   -w      Show only hosts with DOWN HARD state
   -s      Show only services with CRITICAL HARD state
   -r      Compare service/hosts with runbook
   -f	   print result in html
   -d      Last N days
   -o	   Show last N records
EOF
}

function output_html() {
    head -${SHOW} ${1}|\
    awk 'BEGIN { print "<html><table>" }
         {print "<tr><td>" $1 "</td><td>" $2 "</td><td>" $3 "</td><tr>" }
         END { print "</table></html>" }'
}

echoerr() { echo "[$(date +%H:%m:%S)] $@" 1>&2; }

clearfile() { :> ${1} || echo "ERROR: could not clear file ${1}"; }

# functions END

while getopts "h?wsrfd:o:" OPTION
do
    case $OPTION in
         h)
            usage
            exit 1
            ;;
         w)
            CHECKHOST="1"
            CHECKSERVICE="0"
            ;;
         s)
            CHECKHOST="0"
            CHECKSERVICE="1"
            ;;
         r)
            RUNBOOK="1"
            ;;
         d)
            DAYS=$OPTARG
            ;;
         o)
            SHOW=$OPTARG
            ;;
		 f)
            FORMAT="1"
			;;
         ?)
            usage
            exit 1
            ;;
    esac
done

shift $(( OPTIND - 1 ));

if [[ ${RUNBOOK} == "1" ]] &&  [[ ${CHECKHOST} == "1" ]]; then
    echoerr "ERROR: Cant check runbooks for hosts"
    exit 1 
fi 

echoerr "=== Search for the last ${DAYS} days"
echoerr "=== Show TOP ${SHOW} records"

cd $DIR || echoerr "ERROR: Could not change the DIR to ${DIR}"

if [[ -e $FILE ]]; then
	echoerr "Cleaning/creating ${FILE} file";
	clearfile ${FILE}
fi

#HOSTS checks
if [[ ${CHECKHOST} == "1" ]] && [[ ${CHECKSERVICE} == "0" ]]; then

    clearfile ${FILE}
    echoerr "Checking log.gz files for DOWN HARD states for HOSTS"
    echoerr "Please wait...This may take up to 30-60 minutes to complete...";

    for i in `find ${DIRARCH} -type f -name "*.gz" -ctime -${DAYS}`
    do
	echo -n "." 1>&2
	zgrep -E 'DOWN;HARD' $i | awk '{print $5}' | awk -F";" '{print $1}' | grep "ironport.com" >> ${FILE}
    done; echo

    echoerr "Checking unzipped log files for DOWN HARD states for HOSTS"
    echoerr "Please wait...This may take up to 30-60 minutes to complete...";

    for i in `find ${DIR} -type f -name "*.log" -ctime -${DAYS}`
    do
	echo -n "." 1>&2
	egrep 'DOWN;HARD' $i | awk '{print $5}' | awk -F";" '{print $1}' | grep "ironport.com" >> ${FILE}
    done; echo
fi


#Service checks
if [[ ${CHECKSERVICE} == "1" ]]; then

    clearfile ${FILE}
    echoerr "Checking log.gz files for CRITICAL HARD states for SERVICES"
    echoerr "Please wait...This may take up to 30-60 minutes to complete...";

    for i in `find ${DIRARCH} -type f -name "*.gz" -ctime -${DAYS}`
    do
	echo -n "." 1>&2
	zgrep -E 'CRITICAL;HARD' $i |  awk '{print $5}' | awk -F";" '{print $1,$2}' | grep "ironport.com" >> ${FILE}
    done; echo 

    echoerr "Checking unzipped log files for CRITICAL HARD states for SERVICES"
    echoerr "Please wait...This may take up to 30-60 minutes to complete...";

    for i in `find ${DIR} -type f -name "*.log" -ctime -${DAYS}`
    do
	echo -n "." 1>&2
	egrep 'CRITICAL;HARD' $i | awk '{print $5}' | awk -F";" '{print $1,$2}' | grep "ironport.com" >> ${FILE}
    done; echo

fi


# Runbook check
if [[ ${RUNBOOK} == "1" ]]; then
    DATE=`date +%Y/%m/%d -d "-${DAYS} days"`;
    echoerr "Runbook checks... Please standby..."
    echoerr "Report for last ${DAYS} days, so we need runbook from ${DATE}";

    clearfile ${AUDIT_RUNBOOK}
    while read LINE
    do 
	SERVICE=$(echo ${LINE} |awk '{print $2}')
	BOOK=$(grep ${SERVICE} ${RUNBOOKLOG}|awk -F"," '{print $6}')
	[[ ${BOOK} == '' ]] && BOOK="nolink"
	echo "${LINE} ${BOOK}" >> ${AUDIT_RUNBOOK}
    done < <(awk '{print $2}' ${FILE} |sort |uniq -c|sort -rnb)

    echo 1>&2
    echoerr "Total missed runbooks:" `grep -v "OK$" ${AUDIT_RUNBOOK} | wc -l`
else
	clearfile ${AUDIT_NORUNBOOK}
	if [[ ${CHECKSERVICE} == "1" ]]; then
		awk '{print $2}' ${FILE} |sort |uniq -c|sort -rnb > ${AUDIT_NORUNBOOK}
	elif  [[ ${CHECKHOST} == "1" ]]; then
		awk '{print $1}' ${FILE} |sort |uniq -c|sort -rnb > ${AUDIT_NORUNBOOK}
	fi

fi


#Printing results
echo 1>&2
if [[ ${RUNBOOK} == "1" ]]; then
    if [[ $FORMAT == "1" ]]; then
	output_html ${AUDIT_RUNBOOK}
    else 
        head -${SHOW} ${AUDIT_RUNBOOK} || { echoerr "Done. Thank you."; }
    fi    
else 
    if [[ $FORMAT == "1" ]]; then
        output_html ${AUDIT_NORUNBOOK}
    else
	head -${SHOW} ${AUDIT_NORUNBOOK} || { echoerr "Done. Thank you."; }
    fi
fi

echo 1>&2
echoerr "DONE WITH TOP ${SHOW} Alerts"
echoerr "Log File: ${FILE}"

