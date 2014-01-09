#!/usr/local/bin/bash
# $0 <hostname> <snmp_community> <extend>

/usr/bin/snmpget -v2c -c $2 -OQvn $1 .1.3.6.1.4.1.8072.1.3.2.3.1.2.\"$3\"

