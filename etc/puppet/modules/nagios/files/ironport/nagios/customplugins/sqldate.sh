#!/usr/local/bin/bash

WARNING_VAL="$1"
CRITICAL_VAL="$2"

AGE_DAYS=`echo "select FLOOR((UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(MIN(C_DATETIME)))/86400) as days from cresdb.T_AUDITTRAIL" | mysql --host=prod-cres-db-m1.vega.ironport.com --user=nagios --password=thaxu1T | tail -n 1`


if [ "$AGE_DAYS" -ge "$CRITICAL_VAL" ]
then 
    EXIT_CODE="2"

elif [ "$AGE_DAYS" -ge "$WARNING_VAL" ]
then
    EXIT_CODE="1"

else
    EXIT_CODE="0"

fi

MESSAGE="Date is $AGE_DAYS days old."

echo "$MESSAGE"
exit "$EXIT_CODE"


