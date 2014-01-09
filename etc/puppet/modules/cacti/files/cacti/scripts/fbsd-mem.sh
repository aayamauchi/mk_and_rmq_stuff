#!/bin/sh

/usr/bin/snmpget -v2c -c 'y3ll0w!' -OQvn $1 '.1.3.6.1.4.1.8072.1.3.2.3.1.2.3.109.101.109'
