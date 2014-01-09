#!/usr/local/bin/bash
#==============================================================================
# bootleg_ft_counts.sh
#
# Modified version of fozzie_ft_counts.sh, customized for bootleg.
#
# 2011-06-14 jramache
#==============================================================================
PRINT=""
PATH=/bin:/usr/bin:/usr/local/bin

for counter in trainerd:vof_phish_phish:positive_validate_entities:st trainerd:vof_phish_phish:positive_learn_entities:st trainerd:vof_phish_phish:negative_validate_entities:st trainerd:vof_phish_phish:negative_learn_entities:st
do
#    SQL="SELECT sum(value) FROM ft_counts WHERE counter_name LIKE '%${counter}'"
    SQL="SELECT sum(value) FROM ft_counts WHERE counter_name='${counter}'"
    out=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $1 ftdb`
    COLONS=`echo ${counter} | grep -o : | wc -l | sed s/\ //g`
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
echo $PRINT | sed -e 's/positive/pos/g' -e 's/negative/neg/g' -e 's/entities/ent/g' -e 's/validate/val/g'

