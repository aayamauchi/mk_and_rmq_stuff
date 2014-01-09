#!/usr/local/bin/bash

# TRANSFORMS A TYPICAL JIRA EMAIL INTO 2 COMMANDS:
# 1. ACK COMMAND FROM NAGIOS
# 2. JIRA ASSIGNMENT

# STEP 0 -- env

#NAGIOS SETUP
#NAGIOS_HOST=ops-mon-nagios1.vega.ironport.com # host where to run the ack script
NAGIOS_CMD=/usr/local/var/nagios/autoack/ack.local
WHITELIST=~nagios/autoack/whitelist

#JIRA SETUP
JIRA_CMD="~nagios/autoack/bin/jira-cli-4.2/jira"
JIRA_PASSWD_FILE=""

#OTHER
SHOW_VERBOSE=true
SHOW_COMMAND_ONLY=false
IRONCAT_INTEGRATION=true

function echov(){
	if [ SHOW_VERBOSE ]
	then
		echo -ne `date "+%Y/%m/%d-%H:%M:%S\t"`"$$\t$*\n"
	fi
}

function run_command(){
	if [ $SHOW_COMMAND_ONLY == true ]
	then
		echo "***    "$*
	else
		eval $*
		return $?
	fi
}

# STEP 0 -- Init

touch $WHITELIST

# STEP 1 -- reading stdin and retrieve the subject line
SUBJECT_LINE=""
HOST_LINE=""
FROM_LINE=""
TICKET_NUMBER=""
SERVICE_LINE=""
PAGING_LINE=""

# PREVIOUS is the previously updated field.
PREVIOUS=""
while read I
do
	if [ -z "$FROM_LINE" ]
	then
		FROM_LINE=`echo -ne "$I" | egrep '^From:'`
                if [ "$?" = "0" ]
                then
                    PREVIOUS="FROM"
                    continue
                fi
	fi
	if [ -z "$SUBJECT_LINE" ]
	then
		SUBJECT_LINE=`echo -ne "$I" | egrep '^Subject:'`
                if [ "$?" = "0" ]
                then
                    PREVIOUS="SUBJECT"
                    continue
                fi
	fi
	if [ -z "$HOST_LINE" ]
	then
		# this one is a bit tricky, we want to make sure that somewhere we've got at *least* a complete hostname
		HOST_LINE=`echo -ne "$I" | egrep '^[> ]*Host: .*(com|net|org).*'`
                if [ "$?" = "0" ]
                then
                    PREVIOUS="HOST"
                    continue
                fi
	fi
	if [ -z "$SERVICE_LINE" ]
	then
		SERVICE_LINE=`echo -ne "$I" | egrep '^[> ]*Service: .*'`
                if [ "$?" = "0" ]
                then
                    PREVIOUS="SERVICE"
                    continue
                fi
	fi
	if [ -z "$TICKET_LINE" ]
	then
		TICKET_LINE=`echo -ne "$I" | grep "https://jira.ironport.com/browse/"`
                if [ "$?" = "0" ]
                then
                    PREVIOUS="TICKET"
                    continue
                fi
	fi
	if [ -z "$MD5_LINE" ]
	then
		MD5_LINE=`echo -ne "$I" | grep '^[> ]*md5subject: '`
                if [ "$?" = "0" ]
                then
                    PREVIOUS="MD5"
                    continue
                fi
	fi
	if [ -z "$PAGING_LINE" ]
	then
		PAGING_LINE=`echo -ne "$I" | grep "PAGING Nagios"`
                if [ "$?" = "0" ]
                then
                    PREVIOUS="PAGING"
                    continue
                fi
	fi
        echo -ne "$I" | grep "^ "
        if [ "$?" = "0" -a -n "$PREVIOUS" ]
        then
            echo $PREVIOUS
            case "$PREVIOUS" in
                "FROM")
                    FROM_LINE="$FROM_LINE $I"
                    continue ;;
                "SUBJECT")
                    SUBJECT_LINE="$SUBJECT_LINE $I"
                    continue ;;
                "HOST")
                    HOST_LINE="$HOST_LINE $I"
                    continue ;;
                "SERVICE")
                    SERVICE_LINE="$SERVICE_LINE $I"
                    continue ;;
                "TICKET")
                    TICKET_LINE="$TICKET_LINE $I"
                    continue ;;
                "MD5")
                    MD5_LINE="$MD5_LINE $I"
                    continue ;;
                "PAGING")
                    PAGING_LINE="$PAGING_LINE $I"
                    continue ;;
            esac
        else
            PREVIOUS=""
        fi
done 

# STEP 2 -- Extracting the values out of the Subject

echov "$SUBJECT_LINE" 
echov "$FROM_LINE"
echov "$HOST_LINE"
echov "$SERVICE_LINE"
echov "$TICKET_LINE"
echov "$MD5_LINE"
echov "$PAGING_LINE"
echov "--------------------"





######################################
# PARAMETER VALIDATION
######################################

if [ -z "$SUBJECT_LINE" ]
then
	echov "Missing Subject. Exiting."
	exit 2
fi
if [ -z "$HOST_LINE" ]
then
	echov "Missing Host. Exiting."
	exit 2
fi
if [ -z "$FROM_LINE" ]
then
	echov "Missing From. Exiting."
	exit 2
fi
if [ -z "$MD5_LINE" ]
then
	echov "Missing MD5. Exiting."
	exit 2
fi



######################################
# PARAMETER PROCESSING
######################################

# Extracting ticket number
if [ -n "$TICKET_LINE" ]
then
	TICKET_NUMBER=`echo -ne "$TICKET_LINE" | sed 's/.*\/browse\/\([A-Z]*-[0-9]*\).*/\1/g'`
fi

# Extracting User info
FROM_PERSON=`echo -ne "$FROM_LINE\n" | sed 's/.*<\(.*@.*\)>.*/\1/g'`
if [ -z "$FROM_PERSON" ]
then
	echov "Can't extract From Person. Exiting."
	exit 2
fi
USERNAME=`echo -ne "$FROM_PERSON\n" | sed 's/\(.*\)@.*/\1/g'`
if [ -z "$USERNAME" ]
then
	echov "Can't extract Username. Exiting."
	exit 2
fi

# Extracting MD5
MD5=`echo -ne "$MD5_LINE\n" | sed 's/^.*md5subject: \([a-z0-9]*\).*/\1/g'`
if [ -z "$MD5" ]
then
	echov "Can't extract MD5. Exiting."
	exit 2
fi

# Extracting Service Name
if [ -n "$SERVICE_LINE" ]
then
	SERVICE_NAME=`echo -ne "$SERVICE_LINE" | sed -e 's/.*Service: \(.*\) is.*/\1/g'`
	if [ -z "$SERVICE_NAME" ]
	then
		echov "Can't extract Service Name. Exiting."
		exit 2
	fi
fi

# Comment
if [ -n "$TICKET_NUMBER" ]
then
	COMMENT_NAME=$TICKET_NUMBER
else
	COMMENT_NAME="No_ticket"
fi

# Extracting Host name
HOSTNAME=`echo -ne "$HOST_LINE\n" | sed -e 's/^.*Host: //' -e 's/<[^>]*>//g' -e 's/^[(.*) ]*\([a-zA-Z0-9\-]*\.[a-zA-Z0-9\-\.]*\).*$/\1/g'`


#####################################
# Displaying (Verbose only)
#####################################

echov "TICKET NUMBER: $TICKET_NUMBER"
echov "FROM_PERSON: $FROM_PERSON"
echov "USERNAME: $USERNAME"
echov "MD5: $MD5"
echov "SERVICE: $SERVICE_NAME"
echov "HOST: $HOSTNAME"


######################################
# USER VALIDATION
######################################
# checking if the user is a member of sysops

grep sysops /etc/group | grep "$USERNAME" >/dev/null
if [ $? != 0 ]
then
	echov "User NOT in sysops??? Trying with whitelist"
	grep "$FROM_PERSON" $WHITELIST > /dev/null
	if [ $? != 0 ]
	then
		echov "User NOT in WHITELIST either. Exiting"
		exit 3
        else
            FULL_USERNAME=`grep "$FROM_PERSON" $WHITELIST | awk -F ':' '{print $2}'`
	fi
else
    FULL_USERNAME=`grep "$USERNAME" /etc/passwd | awk -F ':' '{print $5}'`
fi


######################################
# MD5 VALIDATION
######################################
# validating with MD5 that the email is authentic
# we start adjusting the Subject line and fix a bug that removes the last space before **
# also fixes a bug when the "is" is stuck to the hostname
# at last, fixes a bug where the hyphen gets stuck to the hostname

final_string=`echo -ne "$SUBJECT_LINE\n" | tr -s "\t" " " |sed -e 's/Subject: //g' -e 's/Re: //g' -e 's/Fwd: //' -e 's/\([^_]\)\*\*$/\1 \*\*/g' -e 's/  \*\*$/ \*\*/g' -e 's/\([^_]\)is /\1 is /g' -e 's/ is\([^_]\)/ is \1/g' -e 's/alert -\([^_]\)/alert - \1/g' -e 's/  / /g'`
supposed_md5=`echo -ne "$final_string" | /sbin/md5`
if [ "$MD5" = "$supposed_md5" ]
then
	echov "OK -- Checksum Passed"
else
	echov "KO -- Failed Checksum"
	echo -ne "$final_string\n"
	echo -ne "$MD5      !=       $supposed_md5\n"
	exit 3
fi


######################################
# ACTION 1 : ACKING
######################################

# Determining if we're in the case where the host is DOWN or a service is CRITICAL

if [ -z "$SERVICE_NAME" ]
then
	echov "HOST $HOSTNAME is DOWN"
	# Acking the host
	run_command $NAGIOS_CMD -u${USERNAME} -c\"${COMMENT_NAME}\" --hostname=\"${HOSTNAME}\"
else
	echov "Service $SERVICE_NAME on $HOSTNAME is alerting"
	# Acking the host
	run_command $NAGIOS_CMD -u${USERNAME} -c\"${COMMENT_NAME}\" -H${HOSTNAME} -S\"${SERVICE_NAME}\"
fi



######################################
# JIRA COMMANDS
######################################

if [ -n "$TICKET_NUMBER" ]
then
	echov "Assigning $TICKET_NUMBER to $USERNAME in JIRA"
	run_command $JIRA_CMD -s https://jira.ironport.com:443 login
	run_command $JIRA_CMD -s https://jira.ironport.com:443 update $TICKET_NUMBER assignee $USERNAME
	run_command $JIRA_CMD -s https://jira.ironport.com:443 comment $TICKET_NUMBER \"Ticket accepted by AUTOACK on behalf of $FROM_PERSON -- https://confluence.ironport.com/display/AUT/AutoAckOpsDoc\"
	run_command $JIRA_CMD -s https://jira.ironport.com:443 logout

fi


######################################
# REPORTS
######################################

if [ $IRONCAT_INTEGRATION ]
then
	run_command "echo \"/me meows : $FULL_USERNAME acked $HOSTNAME/$SERVICE_NAME\" | /usr/bin/nc meow.ironport.com 2345"
	echov "Reported ack in IronCat"
fi

