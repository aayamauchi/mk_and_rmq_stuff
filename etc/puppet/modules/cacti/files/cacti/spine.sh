#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

if [ -e "`dirname $0`/spine.disable" ]
then
        exit 0
fi

ID=`cat /usr/share/cacti/spine.id 2>/dev/null`
if [ "${ID}" == "" ]
then
    ID=`hostname | sed -e 's/[a-z]*//g' -e 's/[-,\.]//g'`
fi

spine --poller ${ID} --stdout --verbosity 3 > /usr/share/cacti/log/spine.log 2>&1
tail -5 /usr/share/cacti/log/spine.log | grep -e "^Time:" | awk '{ print "time:" $2, "hosts:" $7 }' > /usr/share/cacti/log/spine.stat

# retain one extra log run.
cp /usr/share/cacti/log/spine.log /usr/share/cacti/log/spine.log.0

