#!/usr/local/bin/bash

out=`/usr/bin/ssh nagios@prod-sc-www1.soma.ironport.com "grep -e '68.232.128.' -e '68.232.134.' /home/spamcop/bl.spamcop.net.data"`

if [ "" == "$out" ]
then
	echo "No DH hosts detected in Spamcop Blacklist"
	exit 0
fi

for ip in $out
do
	iplist="$iplist$ip "
done

echo "DH ip detected in SpamCop Blacklist [${iplist}]"
exit 2
