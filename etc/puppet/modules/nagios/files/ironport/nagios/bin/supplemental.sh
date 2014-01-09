#!/usr/local/bin/bash

TIMEOUT=/usr/local/ironport/nagios/bin/timeout.pl
SERVICE=$1
HOST=$2

if [ "${SERVICE}" == "System" ]
then
	SERVICE="$1 $2"
        HOST=$3
fi

echo "Output: ${SERVICE} ${HOST}"

case ${SERVICE} in
	ip_mysql_replication-nopage)
		echo SHOW FULL PROCESSLIST:
		echo "show full processlist" | $TIMEOUT 5 mysql -u nagios -pthaxu1T -h${HOST}
		echo SHOW SLAVE STATUS:
		echo "show slave status" | $TIMEOUT 5 mysql -u nagios -pthaxu1T -h${HOST}
		;;
	ip_mysql_replication)
		echo SHOW FULL PROCESSLIST:
		echo "show full processlist" | $TIMEOUT 5 mysql -u nagios -pthaxu1T -h${HOST}
		echo SHOW SLAVE STATUS:
		echo "show slave status" | $TIMEOUT 5 mysql -u nagios -pthaxu1T -h${HOST}
		;;
	ip_toc_history_lag)
		echo SHOW FULL PROCESSLIST:
		echo "show full processlist" | $TIMEOUT 5 mysql -u nagios -pthaxu1T -h${HOST}
		echo SHOW SLAVE STATUS:
		echo "show slave status" | $TIMEOUT 5 mysql -u nagios -pthaxu1T -h${HOST}
		;;
	ip_http_string-accurate)
		echo "Top 10 IPs that have made requests to this host:"
		ssh ${HOST} 'grep -v 192.168 /var/log/httpd/www.senderbase.org/access.log | cut -d"," -f 1 | sort | uniq -c | sort -n |tail'
		;;
	ip_dex_workers)
		ssh ${HOST} 'echo ==== /var/log/messages ====; tail -10 /var/log/messages; echo ==== wbnp_data_server.log ====; tail -200 /data/var/log/web_corpus/wbnp_data_server.log'
		;;
	ip_check_ticket_of_death)
		echo "SELECT tr.Ticket, t.Status, t.Created, t.LastUpdated, COUNT(*) AS 'AttachmentCount' FROM rt3.Tickets t, rt3.Transactions tr, rt3.Attachments at WHERE tr.id=at.TransactionId AND tr.Ticket=t.id AND t.LastUpdated > date_sub(now(),INTERVAL 1 HOUR) AND t.Status != 'rejected' GROUP BY tr.Ticket, t.Created HAVING COUNT(*) > 1000" | $TIMEOUT 5 mysql -u nagios -pthaxu1T -h${HOST} rt3
		;;
	check_mysql_processlist-cres)
		/usr/local/ironport/nagios/customplugins/check_mysql_process.py -H ${HOST} -u 'nagios' -p 'thaxu1T' -w 100 -c 200 -P
		;;
	check_mysql_processlist-corpus)
		/usr/local/ironport/nagios/customplugins/check_mysql_process.py -H ${HOST} -u 'nagios' -p 'thaxu1T' -w 3600 -c 7200 -P
		;;
	ip_ipmi)
		ssh ${HOST} 'echo ==== /var/run/ipmi_fault_detected ====; cat /var/run/ipmi_fault_detected'
		;;

esac
echo "========================================"
echo "Command run as nagios user:"
COMMAND=`/usr/local/ironport/nagios/bin/nagios_command.py -H ${HOST} -S "${SERVICE}" 2>&1`
echo ${COMMAND}
