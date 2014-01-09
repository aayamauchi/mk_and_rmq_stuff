#!/usr/local/bin/bash

# TRANSFORMS A TYPICAL JIRA EMAIL INTO 2 COMMANDS:
# 1. ACK COMMAND FROM NAGIOS
# 2. JIRA ASSIGNMENT

# STEP 0 -- env

WHITELIST="~sledigab/.procmail/whitelist"
ARCHIVE_PLACE="~sledigab/.procmail/archive"

#NAGIOS SETUP
NAGIOS_HOST=ops-mon-nagios1.vega.ironport.com # host where to run the ack script
NAGIOS_CMD='/usr/local/ironport/nagios/bin/ack'

#JIRA SETUP
JIRA_CMD="~sledigab/.procmail/bin/jira-cli-4.2/jira"
JIRA_USER="sledigab"
JIRA_PASSWD_FILE=""

#OTHER
#SHOW_COMMAND_ONLY=false
SHOW_COMMAND_ONLY=true

function run_command(){
	if [ $SHOW_COMMAND_ONLY == true ]
	then
		echo "***    "$*
	else
		eval $*
		return $?
	fi
}

function verify_user(){
	#################################################################
	# CHECKING IF THE USERNAME IS IN SYSOPS OR IN THE WHILELIST     #
	#################################################################

	if $SHOW_COMMAND_ONLY
	then
		echo "Verifying if $1 is in _sysops_"
	fi
	grep "^sysops" /etc/group | grep $1 || grep "^${1}$" $WHITELIST || exit 1
	
}

# STEP 1 -- reading stdin and retrieve the subject line
SUBJECT_LINE=""
HOST_LINE=""
FROM_LINE=""
while [ ! "$SUBJECT_LINE" ] && [ ! "$HOST_LINE" ]
do
	read -e I 
	if [ -z "$FROM_LINE" ]
	then
		FROM_LINE=`echo -ne "$I" | egrep '^From:'`
	fi
	if [ -z "$SUBJECT_LINE" ]
	then
		SUBJECT_LINE=`echo -ne "$I" | egrep '^Subject:'`
	fi
	if [ -z "$HOST_LINE" ]
	then
		HOST_LINE=`echo -ne "$I" | egrep '^\*Host:\*'`
	fi
done

# STEP 2 -- Extracting the values out of the Subject

echo -ne "$SUBJECT_LINE\n"
echo -ne "$FROM_LINE\n"
TICKET_NUMBER=`echo -ne "$SUBJECT_LINE" | sed 's/.*\(SYSOPS-[0-9]*\).*/\1/g'`
FROM_SERVER=`echo -ne "$FROM_LINE\n" | sed 's/.*<.*@\(.*\)>.*/\1/g'`
USERNAME=`echo -ne "$FROM_LINE\n" | sed 's/.*<\(.*\)@.*/\1/g'`


# checking if the user can do that, i.e. if the user is a member of sysops
verify_user $USERNAME $FROM_SERVER


echo
GROUP_VALUE=`echo -ne "$SUBJECT_LINE" | sed 's/^.*- \(.*\) is .*/\1/g'`
HOST_DOWN=`echo -ne "$SUBJECT_LINE" | grep DOWN`

echo  -ne "$TICKET_NUMBER --- $FROM_PERSON\n"
#echo -ne "$HOST_NAME\n"
if [ "$HOST_DOWN" == "" ]
then
	echo "this is a service that failed"
	HOSTNAME=`echo $GROUP_VALUE | awk -F '/' '{print $1}'`
	SERVICENAME=`echo $GROUP_VALUE | awk -F '/' '{print $2}'`
	echo "acking service $SERVICENAME on hostname $HOSTNAME"
	run_command ssh root@$NAGIOS_HOST \"$NAGIOS_CMD -H $HOSTNAME -S $SERVICENAME -u $USERNAME -c $TICKET_NUMBER\"
fi
	

echo "assigning ticket $TICKET_NUMBER to : $FROM_PERSON"
run_command $JIRA_CMD -s https://jira.ironport.com:443 login
run_command $JIRA_CMD -s https://jira.ironport.com:443 update $TICKET_NUMBER assignee $USERNAME
run_command $JIRA_CMD -s https://jira.ironport.com:443 comment $TICKET_NUMBER \"Ticket accepted by AUTOACK\"
run_command $JIRA_CMD -s https://jira.ironport.com:443 logout


