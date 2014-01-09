#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

snmpget -v2c -c $2 -OQvn $1 .1.3.6.1.4.1.8072.1.3.2.3.1.2.\"bindstats\"

