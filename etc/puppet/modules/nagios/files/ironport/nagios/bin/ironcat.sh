#!/bin/sh
# ironcat helper script, stolen from:
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/bin/ironcat.sh#4 $
#

BOT_HOST='ops-dev1.sv4.ironport.com'
BOT_PORT='2345'
BOT_MESG="$1"
PATH='/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin'
export PATH

echo "/me ${BOT_MESG}" | nc -w 5 ${BOT_HOST} ${BOT_PORT} > /dev/null 2>&1

# eof
