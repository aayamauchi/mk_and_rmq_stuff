#!/bin/env bash

# Scritp checks if partition is mounted on the remote server.

EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNK=3

usage(){
    cat << EOF
USAGE: $(basename $0) -h <hostname> -c <snmp_community> -d "<partition>" -v <verbosity>
Returns: OK       - if found.
         Critical - if not found.
         Unknown  - remaining states.
EOF
}

Host=""
Community=""
Directory=""
verbose=0

while getopts h:c:d:v ARGS
do
    case $ARGS in
        h) Host=$OPTARG
        ;;
        c) Community=$OPTARG
        ;;
        d) Directory=$OPTARG
        ;;
        v) verbose=1
        ;;
        *) echo "Unknown Variable $ARGS"
           usage
           exit $EXIT_UNK
        ;;
    esac
done

for reqopt in Host Community Directory
do
    if [ -z ${!reqopt} ]
    then
        echo -e "$reqopt MUST be specified\n"
        usage
        exit $EXIT_UNK
    fi
done

TmpOUT=$(snmpwalk -v2c -c ${Community} -OvQn ${Host} hrFSRemoteMountPoint 2>&1 )
err_code=$?
TmpOUT=$(echo $TmpOUT | tr -d \" | sed '/^$/d')

[[ $verbose -gt 0 ]] && {
        echo "SNMP Query Output :: $TmpOUT "
        echo "Querie's Exit Code :: $err_code"
}

if [[ $err_code -ne 0 ]]
then
        echo "Exiting with UNKNOWN state"
        echo "UNKNOWN. $TmpOUT "
        exit $EXIT_UNK
else
        OUT=$( echo $TmpOUT | grep -Ei "${Directory}" )
        code=$?
        if [ $code -ne 0 ]
        then
                [[ $verbose -gt 0 ]] && {
                        echo "Error Occured"
                        echo "Partition $Directory is not mounted at $Host "
                        echo "CRITICAL"
                }
                echo "CRITICAL. Partition $Directory is not mounted at $Host "
                exit $EXIT_CRIT
        else
                echo "OK. Partition $Directory is mounted at $Host "
                exit $EXIT_OK
        fi
fi
