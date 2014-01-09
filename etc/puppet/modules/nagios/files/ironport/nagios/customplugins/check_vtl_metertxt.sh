#!/bin/sh
#
# meter.txt file age monitor.
# Grabs the timestamp from the meter.txt file and compares it to current time.

CURRENT=`date +%s`
FILE=`wget -q -O - http://stage-downloads.soma.ironport.com/vtl/meter.txt | cut -d ' ' -f 4`
OFFSET=`expr ${CURRENT} "-" ${FILE}`

if [ ${OFFSET} -ge 1200 ]; then
echo "CRITICAL - vtl meter.txt age older then 1200 seconds - currently ${OFFSET}"
exit 2
fi
if [ ${OFFSET} -ge 600 ]; then
echo "WARNING - vtl meter.txt age older then 600 seconds - currently ${OFFSET}"
exit 1
fi
echo "OK - vtl meter.txt currently ${OFFSET}"
