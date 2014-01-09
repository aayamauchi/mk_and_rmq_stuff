#!/bin/bash


AGE=`echo \`date +%s\` - \`stat --format=%Y /var/spool/mail/cres\` | bc`


if [ ${AGE} -lt 600 ];
then
    echo > /var/spool/mail/cres
fi
