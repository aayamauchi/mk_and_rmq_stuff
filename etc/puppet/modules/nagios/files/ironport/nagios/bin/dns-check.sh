#!/usr/local/bin/bash

/usr/local/nagios/libexec/check_dns -H smtp.vega.ironport.com -c 15 -t 20 >/dev/null 2>&1

if [ $? -ne 0 ]
then
    # host resolution skipped due to /etc/hosts entry.
    ssh -i ~nagios/.ssh/id_rsa -q -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=2 nagios@nagios1.ext.ironport.com "echo Vegas DNS outage | mail -s alert 8082835030@vtext.com,4153096791@txt.att.net"
fi
