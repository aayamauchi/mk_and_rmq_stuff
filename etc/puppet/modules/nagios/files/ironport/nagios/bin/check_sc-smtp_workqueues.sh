#!/bin/sh
# 
# Simple scriptlet to check on the workqueues of all 4 sc-smtp MGA/ESA hosts
# 

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/ironport/nagios/customplugins

for i in 1 2 3 4 5 6 7 8 9 10; do
	echo -n "sc-smtp${i}   "
	check_c60_workqueue.py -H sc-smtp${i}.soma.ironport.com -u admin -p 0zzieMan -w 25000 -c 75000
done

