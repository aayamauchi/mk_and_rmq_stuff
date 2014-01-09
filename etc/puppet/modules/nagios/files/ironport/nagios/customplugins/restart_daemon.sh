#!/bin/sh

env > /tmp/nagios.env
set >> /tmp/nagios.env

echo [`date`] $1/$2 $3: $4:$5:$6 >> /tmp/restart_daemon.out
#
# ssh to remote server, attempt to restart on second soft failure, via sudo
#
# Mike Lindsey - 11/26/2007
# $0 $HOSTADDRESS$ $SERVICENAME$ $RESTARTSCRIPT$ $SERVICESTATE$ $STATETYPE$ $SERVICEATTEMPT$
# ./$0 corpus2-www1.soma.ironport.com glass-httpd corpus-web.sh CRITICAL SOFT 2

# NOTE -- dannhowa changed the case statement from CRITICAL to WARNING
# or CRITICAL -- 2008-02-26
#
# Got uglified for postx restarts.  Being replaced with a new system Real Soon Now
# miklinds - 2009-04-15

if [ "$7" == "" ]
then
	RCPATH=/usr/local/etc/rc.d
	RESTART="restart"
else
	RCPATH=/etc/init.d
	RESTART="restart thread"
fi


# What state is the service in?
case "$4" in
OK)
	# Whee, do nothing
	echo > /dev/null
        ;;
*)

	# Is this a "soft" or a "hard" state?
	case "$5" in
	# We're in a "soft" state, meaning that Nagios is in the middle of retrying the
	# check before it turns into a "hard" state and contacts get notified...
	SOFT)
			
		# What check attempt are we on?  We don't want to restart the web server on the first
		# check, because it may just be a fluke!
		if [ "$3" == "postx" ]
		then
			if [ "$4" != "CRITICAL" ]
			then
				exit
			fi
		fi
		case "$6" in
		2)
			if [ "$3" == "postx" ]
			then
			    /usr/local/nagios/libexec/check_http -H $1 -w "5" -c "10" -u "/keyserver/keyserver?su=ie-monitor%40ironport.com&k=base64%3asha1%2c9xwZlE4aLr7ktX0m0aMIYLJgO10%3d&v=2&m=e9ea7d68c549da0e0afb166bc22d755c&s=2&f=2&action=open" -s "success=true" -t "15" -S 2>&1 > /dev/null
			    if [ $? -ne 2 ]
			    then
			    	echo "Key check exit != 2"
				exit
			    fi
			fi
			echo -n "Restarting $1/$2 $5 $4 # $6..."
			# Call the init script to restart service
			/usr/bin/ssh nagios@$1 "sudo ${RCPATH}/$3 ${RESTART}" 2>&1 >> /tmp/restart_daemon.out
			;;
		3)
			if [ "$3" == "postx" ]
			then
			    /usr/local/nagios/libexec/check_http -H $1 -w "5" -c "10" -u "/keyserver/keyserver?su=ie-monitor%40ironport.com&k=base64%3asha1%2c9xwZlE4aLr7ktX0m0aMIYLJgO10%3d&v=2&m=e9ea7d68c549da0e0afb166bc22d755c&s=2&f=2&action=open" -s "success=true" -t "15" -S 2>&1 > /dev/null
			    if [ $? -ne 2 ]
			    then
			    	echo "Key check exit != 2"
				exit
			    fi
			fi
			echo -n "Restarting $1/$2 $5 $4 # $6..."
			# Call the init script to restart service
			/usr/bin/ssh nagios@$1 "sudo ${RCPATH}/$3 ${RESTART}" 2>&1 >> /tmp/restart_daemon.out
			;;
		esac
		;;
				
	esac
	;;
esac
exit 0


