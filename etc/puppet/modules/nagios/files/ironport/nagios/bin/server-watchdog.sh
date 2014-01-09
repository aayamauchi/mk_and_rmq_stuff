#!/usr/local/bin/bash

# screams really loud if other server goes down.
# takes over, then fails back.

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
hostname=$1
localhost=`hostname`
config=$2

dns=`host $1 2>/dev/null | grep -v "not found"`


if [ "${localhost}" == "${hostname}" ]
then
    echo This should not be run against the local host.
    echo That will only result in a startup/shutdown loop, and a lot of email.
    exit
fi

RECIPIENTS_FILEPATH="/usr/local/nagios/etc-external/pager_emails.txt"
RECIPIENTS_FAILSAFE="4153096791@messaging.sprintpcs.com 8082835030@vtext.com"

RECIPIENTS=""
if [ -e "${RECIPIENTS_FILEPATH}" ]; then
    RECIPIENTS="`cat ${RECIPIENTS_FILEPATH}`"
fi

if [ "${RECIPIENTS}" = "" ]; then
    RECIPIENTS=${RECIPIENTS_FAILSAFE}
fi

# if not in DNS, someone's screwed up somewhere.
if [ "${dns}" != "" ]
then

ping=`/usr/local/nagios/libexec/check_ping -H 192.168.102.103 -w 20,20% -c 50,30%`
pingret=$?
if [ "${pingret}" != "0" ]; then
# problem!
    sleep 30
    ping=`/usr/local/nagios/libexec/check_ping -H 192.168.102.103 -w 20,20% -c 50,30%`
    pingret=$?
    if [ "${pingret}" != "0" ]; then
    # still a problem!
        if [ ! -f /tmp/master ]
        then
            for email in ${RECIPIENTS}
            do
                printf "%b" "${date} : Nagios ${hostname} host experiencing: ${ping}\n
Failing over to ${localhost}" | mail -s "${hostname} nagios down" ${email}
            done
            printf "%b" "${date} : Nagios ${hostname} host experiencing: ${ping}\n
Failing over to ${localhost}" | mail -s "${hostname} nagios down" stbu-systemops@cisco.com
            touch /tmp/master
            #/usr/local/etc/rc.d/apache22 start
            service nagios start
            #/usr/local/etc/rc.d/postfix start
            #/usr/local/etc/rc.d/xinetd start
            #/usr/local/etc/rc.d/snmptrapd start
            /usr/local/ironport/nagios/bin/notification_server.py --start
            /usr/local/ironport/nagios/bin/nagiosstatd > /usr/local/nagios/var/statd.log 2>&1 &
        else
            echo "Already master"
        fi
    fi
else
    if [ -f /tmp/master ]
    then
        # Shut down everything that might be running, since the other server is fine
        rm /tmp/master
        #/usr/local/etc/rc.d/apache22 stop
        service nagios stop
        #/usr/local/etc/rc.d/xinetd stop
        #/usr/local/etc/rc.d/snmptrapd stop
        /usr/local/ironport/nagios/bin/notification_server.py --stop
        for email in ${RECIPIENTS}
        do
            printf "%b" "${date} : Nagios ${hostname} host recovered: ${ping}\n
Failing back" | mail -s "${hostname} nagios up" ${email}
        done
        printf "%b" "${date} : Nagios ${hostname} host recovered: ${ping}\n
Failing back" | mail -s "${hostname} nagios up" stbu-systemops@cisco.com
        # Give time for all the mail to drain from the queue.
        #sleep 15; /usr/local/etc/rc.d/postfix stop

    fi
fi

else 
	echo "Unknown hostname"
fi
