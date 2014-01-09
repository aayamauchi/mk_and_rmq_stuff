#!/usr/local/bin/bash

OK=0
WA=0
CR=0

for host in $2
do
	OUT=`/usr/local/nagios/libexec/check_tcp -H $host -p $1`
	EXIT=$?

	if [ ${EXIT} -eq 0 ]; then OK=1; continue; fi
	if [ ${EXIT} -eq 1 ]; then WA=1; continue; fi
	if [ ${EXIT} -eq 2 ]; then CR=1; continue; fi
done


if [ ${OK} -eq 0 ];
then
	echo "All hosts ($2) in cluster reporting non-ok state for port $1"
	exit 2
fi

echo "At least one host ($2) in cluster reporting ok state for port $1"
exit 0
