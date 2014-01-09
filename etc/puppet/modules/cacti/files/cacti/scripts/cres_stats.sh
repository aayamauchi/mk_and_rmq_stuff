#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

time=`date +%s`
script="perl /usr/share/cacti/scripts/timeout.pl -9 5 python26 /usr/share/cacti/scripts/check_mysql_data.py -H $1 -u cactiuser -p cact1pa55 -d sysops --cacti -q "
accounts=`${script} 'select C_VALUE from T_CACTI_MONITORING where C_NAME="TOTAL_ACCOUNTS"'`
users=`${script} 'select C_VALUE from T_CACTI_MONITORING where C_NAME="TOTAL_USERS"'`
keys=`${script} 'select C_VALUE from T_CACTI_MONITORING where C_NAME="TOTAL_KEYS_INSERTED"'`

echo Time:$time Accounts:$accounts Keys:$keys Users:$users

