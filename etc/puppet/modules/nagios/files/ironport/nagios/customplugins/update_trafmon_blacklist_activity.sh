#!/usr/local/bin/bash

# Check updates mount for trafmon blacklist activity.
# Alert if no activity in last 10 days.

OUT=`/usr/bin/ssh nagios@$1 "/usr/bin/find /usr/local/ironport/updates/trafmon/blacklist/ -mtime -10d -type f" 2>/dev/null`

if [ "${OUT}" == "" ]
then
    echo "No activity in /usr/local/ironport/updates/trafmon/blacklist/ for > 10 days."
    exit 2
else
    echo "Activity in /usr/local/ironport/updates/trafmon/blacklist/ in last 10 days."
    exit 0
fi
