#!/bin/env bash

# Script created due to MONOPS-1405.
# Proactive monitoring of ACE-4710 Uptime.

EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNK=3

usage() {
    cat << EOF
  USAGE: $(basename $0) -H <host> -C <SNMP community> -o <SNMP OID> -w <warning> -c <critical> -v <verbosity> -h <help>
  -H hostname/host address 
  -C SNMP community to use.
  -o SNMP OID to retrieve. If oid not specified, default value is used (sysUpTime.0)
  -w warning threshold. Default :: 0 (zero)
  -c critical threshold. Default :: 0 (zero)
  -h help. Display this help message and exit.
  -v verbosity. Default :: Off
EOF
}

if [[ $# -lt 4 ]] 
then
   usage
   exit $EXIT_UNK
fi

SNMPGET=$(which snmpget)
Host=""
community=""
oid="sysUpTime.0"
method="get"
warn=0
crit=0
verbose=0

while getopts H:C:o:w:c:vh ARGS
do
    case $ARGS in 
        H) Host="$OPTARG"
        ;;
        C) community="$OPTARG"
        ;;
        o) oid="$OPTARG"
        ;;
        w) warn=$OPTARG
        ;;
        c) crit=$OPTARG
        ;;
        v) verbose=1
        ;;
        h) usage
           exit $EXIT_UNK
        ;;
        *) usage
           exit $EXIT_UNK
        ;;
    esac
done

[[ $verbose -gt 0 ]] && {
    echo "Host      : $Host"
    echo "Community : $community"
    echo "oid       : $oid"
    echo "Warning   : $warn"
    echo "Critical  : $crit"
    echo "SnmpGet   : $SNMPGET"
}

if [[ -z $Host ]] || [[ -z $community ]] 
then
    [[ $verbose -gt 0 ]] && {
        echo -e "\nVariables : HOST and Community are Mandatory "
        echo "Host      : $Host"
        echo -e "Community : $community \n"
    }
    usage
    exit $EXIT_UNK
fi

# Warning Threshold should be less then Critical threshold

if [[ $warn -gt $crit ]]
then
    echo "Warning Threshold should not be greater then Critical"
    exit $EXIT_UNK
fi

# Retrieving data

Data=$(${SNMPGET} -v2c -c "${community}" -OvQ ${Host} ${oid} 2>&1) 

if [[ -n $(echo $Data | egrep -i "timeout|unknown|no such") ]]
then
    echo "UNKNOWN: Cannot retrive SNMP data :: $Data "
    exit $EXIT_UNK
else
    Days=$(echo $Data | awk -F ":" '{print $1}')
fi

# Comparing resulte

if [[ $Days -lt $warn ]] 
then
    echo "OK. ${Host}'s Uptime is $Days "
    exit $EXIT_OK
fi

if [[ $Days -ge $warn ]] && [[ $Days -lt $crit ]]
then
    echo "WARNING. ${Host}'s Uptime is $Days "
    exit $EXIT_WARN
fi

if [[ $Days -ge $crit ]]
then
    echo "CRITICAL. ${Host}'s Uptime is $Days "
    exit $EXIT_CRIT
fi
