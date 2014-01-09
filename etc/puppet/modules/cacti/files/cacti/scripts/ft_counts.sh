#!/usr/local/bin/bash
# $0 host numindexes
# $0 host index
# $0 host query field
# $0 host get field $index

PATH=/bin:/usr/bin:/usr/local/bin

if [ "$1" == "" ] || [ "$2" == "" ]
then
    echo "USAGE: $0 dbhostname [index|query <field>|get <field> <index>]"
elif [ "$2" == "numindexes" ]
then
    SQL="SELECT count(distinct(counter_name)) FROM ft_counts WHERE counter_name NOT LIKE '%.rate'"
    out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
    echo $out
elif [ "$2" == "index" ] 
then
    SQL="SELECT distinct(counter_name) FROM ft_counts WHERE counter_name NOT LIKE '%.rate' ORDER BY counter_name"
    out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
    index=0
    for item in $out
    do
        echo $index
        index=$(($index+1))
    done
elif [ "$2" == "query" ] 
then
    if [ "$3" == "" ]
    then
        echo "Must supply parameter to query"
    else
        SQL="SELECT distinct(counter_name) FROM ft_counts WHERE counter_name NOT LIKE '%.rate' ORDER BY counter_name"
        out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
        index=0
        for item in $out
        do
            if [ "$3" == "value" ]
            then
                # Something here to not sum up timestamps?
                SQL="SELECT sum($3) FROM ft_counts WHERE counter_name=\"$item\""
                out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
            else
                SQL="SELECT distinct($3) FROM ft_counts WHERE counter_name=\"$item\""
                out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
            fi
            echo "$index!$out"
            index=$(($index+1))
        done
    fi
elif [ "$2" == "get" ]
then
    if [ "$3" == "" ] || [ "$4" == "" ]
    then
        echo "Must supply parameter and index to get"
    else
        SQL="SELECT distinct(counter_name) FROM ft_counts WHERE counter_name NOT LIKE '%.rate' ORDER BY counter_name"
        out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
        index=$(($4+1))
        item=`printf "%b" "$out" | head -$index | tail -1`
        if [ "$3" == "value" ]
        then
            # Something here to not sum up timestamps?
            SQL="SELECT sum($3) FROM ft_counts WHERE counter_name=\"$item\""
            out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
        else
            SQL="SELECT distinct($3) FROM ft_counts WHERE counter_name=\"$item\""
            out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
        fi
        printf "%b" "$out\n"
    fi
fi
