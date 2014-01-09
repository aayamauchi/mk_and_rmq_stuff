#!/usr/local/bin/bash

dns=`curl -k https://atlas.iphmx.com/atlas/dns/tinydns/ext/ 2>/dev/null`
host=`printf "%s" "${dns}" | grep '^C' | grep -e "dh...-$1" | sort | head -1 | cut -c2- | cut -f1 -d:`

/usr/local/nagios/libexec/check_http -t 15 -H $host -f follow --ssl -s "IronPort"
exit $?
