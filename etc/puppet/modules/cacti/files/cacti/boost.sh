#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

if [ -e "`dirname $0`/boost.disable" ]
then
        exit 0
fi

cd /usr/share/cacti/log
l="boost.log"
rm $l.5; mv $l.4 $l.5; mv $l.3 $l.4; mv $l.2 $l.1; mv $l $l.1
php -q /usr/share/cacti/plugins/boost/poller_boost.php -f -v > /usr/share/cacti/log/boost.log 2>&1
