#!/usr/local/bin/bash

PATH=/bin:/usr/bin

SQL="select counter_name, value from ft_counts where counter_name like '%.capacity.${1}'"

RESULTS=`echo ${SQL} | mysql -N -u cactiuser -pcact1pa55 -h $2 whiskey_ft`

PRINT=""

for x in ${RESULTS}
do
   DOTS=`echo ${x} | grep -o "\." | wc -l | sed s/\ //g`
   if [ $DOTS -eq 0 ]
   then
       PRINT="${PRINT}:${x} "
   else
       DOTS=`echo "${DOTS} - 1" | bc`
       PRINT="${PRINT}`echo ${x} | awk -F . '{ print $'${DOTS}' }' | tr -d _`"
   fi
done

echo $PRINT
