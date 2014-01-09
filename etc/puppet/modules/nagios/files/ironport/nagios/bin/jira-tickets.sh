#!/usr/local/bin/bash
#
# Script to get latest ticket, or provide search if it can't

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/bin


if [ "$2" == "" ]
then
    # Try and get the latest ticket.
    TKT=`jira getissues "Summary ~ '%$1%is%' AND Resolution=Unresolved AND Project != OPS" 2>/dev/null | tail -1`
    URL="https://jira.sco.cisco.com/secure/QuickSearch.jspa?searchString=Summary~'$1'"
else
    # Try and get the latest ticket.
    TKT=`jira getissues "Summary ~ '%$1/$2%' AND Resolution=Unresolved AND Project != OPS" 2>/dev/null | tail -1`
    URL="https://jira.sco.cisco.com/secure/QuickSearch.jspa?searchString=Summary~'$1/$2'"
fi

TKT=`echo ${TKT} | cut -d, -f1`
if [ "${TKT}" != "" ]
then
    echo "https://jira.sco.cisco.com/browse/${TKT}"
fi
echo "${URL}"
