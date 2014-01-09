#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/bin
PW=`nagios-ldap-htpwgen.py 2>&1`
ONE=$?

INC="/usr/local/ironport/akeos/bin/htpass-include.py"
if [ -x $INC ]
then
    $INC
    TWO=$?
    cp /usr/local/nagios/etc/htpasswd.include /usr/local/nagios/etc-ops-mon-nagios1.vega/ >/dev/null 2>&1
else
    ls -l /usr/local/nagios/etc/htpasswd.include >/dev/null 2>&1
    TWO=$?
fi


if [ "${ONE}${TWO}" == "00" ]
then
    printf "%s" "$PW" > /usr/local/nagios/etc/htpasswd.users
    cat /usr/local/nagios/etc/htpasswd.include >> /usr/local/nagios/etc/htpasswd.users
else
    printf "%s" "Error Generating htpasswd
Main:${ONE} Secondary:${TWO}" | /usr/bin/mail -s "Nagios HTPasswd error on `hostname`" stbu-monops-level1@cisco.com
fi

