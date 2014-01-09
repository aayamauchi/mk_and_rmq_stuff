#!/usr/local/bin/bash
GROUP="${1}"
if [ "${GROUP}" == "" ]; then
    GROUP="prodops"
fi
GROUP_TITLE=""
case "${GROUP}" in
    "dba"        ) GROUP_TITLE="Database";;
    "monops"     ) GROUP_TITLE="Monitoring";;
    "netops"     ) GROUP_TITLE="Network";;
    "platops"    ) GROUP_TITLE="Platform";;
    "platopskfa" ) GROUP_TITLE="PlatformKFA";;
    "prodops"    ) GROUP_TITLE="Production";;
    "storage"    ) GROUP_TITLE="Storage";;
    *            ) GROUP_TITLE="System";;
esac
ONCALL=`/usr/local/ironport/nagios/bin/viewoncall --reminder --show=${GROUP}`
EMAILS=`echo "${ONCALL}" | grep 'email_recipients' | head -1 | awk -F'|' '{print $2}'`
EMAILS="-cstbu-monops-level1@cisco.com,ops_lviv@cisco.com ${EMAILS}"
TZINFO="`date +%Z` (GMT`date +%z`)"
TODAY=`date +'%m/%d/%Y'`
if `uname -s | grep Linux 1>/dev/null 2>/dev/null`; then
   NEXT_WEEK=`date --date='1 week' +'%m/%d/%Y'`
else
   NEXT_WEEK=`date -v+1w +'%m/%d/%Y'`
fi
MESG=`echo "${ONCALL}" | grep -v 'email_recipients'`
MESG="Hello, this is a reminder that you are on call for the next seven days (${TODAY} to ${NEXT_WEEK}) in support of the Cisco IronPort ${GROUP_TITLE} Operations Team. Please review your assignment(s), listed below. All times shown are ${TZINFO}.

${MESG}

Thank you, we sincerely hope that it is a quiet week for you.
--
Cisco IronPort Systems, LLC
Security Cloud Operations
Monitoring Operations Team

This reminder was sent from the master monitoring node (`hostname`) following the weekly on call rotation. Only one reminder will be sent for the week, therefore please keep others informed if changes are made to the schedule. Direct all questions and concerns to stbu-monops@cisco.com.

NOTICE: This email may contain confidential and privileged material for the sole use of the intended recipient. Any review, use, distribution or disclosure by others is strictly prohibited. If you are not the intended recipient (or authorized to receive for the recipient), please contact stbu-monops@cisco.com and delete all copies of this message. For corporate legal information go to: http://www.cisco.com/web/about/doing_business/legal/cri/index.html

PLEASE DO NO REPLY TO THIS EMAIL"

if [ "${EMAILS}" != "" ]; then
    printf "%b" "${MESG}" | mail -s "REMINDER: ${GROUP_TITLE} Operations On Call Status" ${EMAILS}
fi
