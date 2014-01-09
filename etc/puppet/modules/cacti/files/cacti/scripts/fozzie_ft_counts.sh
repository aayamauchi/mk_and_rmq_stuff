#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

PRINT=""

for counter in clusterconnection:active:dyn clusterstore:num_clusters:dyn clusterstore:num_msgs:dyn clusterstore:lookup:lookups:dyn ham_manager:status_counters:ham_queue_size:st
do
   SQL="SELECT sum(value) FROM ft_counts WHERE counter_name LIKE '%${counter}'"
    out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
    COLONS=`echo ${counter} | grep -o : | wc -l | sed s/\ //g`

    # uncomment for debugging
    #echo "Counter: $counter"
    #echo "Query: $SQL"
    #echo "Result: $out"
    #echo

    DOTS=`echo ${counter} | grep -o "\." | wc -l | sed s/\ //g`
    DOTSN=`echo ${DOTS} + 1 | bc`
    
    counter=`echo ${counter} | awk -F : '{ print $'${COLONS}' }' | tr -d _`
    if [ $DOTS -ne 0 ]
    then
        counter=`echo ${counter} | awk -F . '{ print $'${DOTS}'$'${DOTSN}' }'`
    fi
    PRINT="${PRINT}${counter}:${out} "
done

# truncate to 19 characters for rrdtool local data source name restriction
echo $PRINT | sed -e 's/outputqueuefull/oqf/' | sed -e 's/packets/pkt/' | \
    sed -e 's/adapter/adptr/'

