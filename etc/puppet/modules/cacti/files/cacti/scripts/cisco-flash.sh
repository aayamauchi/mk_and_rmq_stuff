#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

if [ "$3" == "" ]
then
    echo must pass [hostname] [snmpcommunity] [command]
    echo where command is one of index, query, get
    exit
fi

case "$3" in
    "index")
        index=`snmpwalk -OQv -v 2c -c $2 $1 .1.3.6.1.4.1.9.9.10.1.1.2.1.7`
        x=1
        for val in $index
        do
            printf "%b" "${x}\n"
            x=`echo $x + 1 | bc`
        done
        echo
        ;;
    "query")
        index=`snmpwalk -OQv -v 2c -c $2 $1 .1.3.6.1.4.1.9.9.10.1.1.2.1.7`
        x=1
        for val in $index
        do
            printf "%b" "${x}:${val}\n" | tr -d \"
            x=`echo $x + 1 | bc`
        done
        echo
        ;;
    "get")
        if [ "$4" == "" ]
        then
            echo Must pass target to get
            exit
        fi
        if [ "$4" == "Size" ]
        then
            snmpwalk -OQv -v 2c -c $2 $1 .1.3.6.1.4.1.9.9.10.1.1.4.1.1.13.$5.1
        elif [ "$4" == "Avail" ]
        then
            snmpwalk -OQv -v 2c -c $2 $1 .1.3.6.1.4.1.9.9.10.1.1.4.1.1.14.$5.1
        fi
        ;;
esac
