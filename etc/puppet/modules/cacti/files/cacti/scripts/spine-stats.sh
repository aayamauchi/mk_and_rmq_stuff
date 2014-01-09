#!/bin/sh

/usr/bin/ssh -i /var/www/.ssh/id_nagios -o StrictHostKeyChecking=no -o ConnectTimeout=2 nagios@$1 "cat /usr/share/cacti/log/spine.stat" 2>/dev/null
