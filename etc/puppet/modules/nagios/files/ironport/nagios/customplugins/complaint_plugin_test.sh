#!/bin/sh

PATH=/bin:/usr/bin:/usr/local/bin
#grab the first command line argument
if [ -n "${1}" ]; then
        hostname="${1}"
else
        echo "I didnt get passed the URL to test.  I'm going to go cry now."
	echo
	echo "My only command line option is a full URL to be tested."
	echo
        exit
fi

if `curl -s --connect-timeout 10 --insecure ${hostname} | grep -q "Outlook plugin server started successfully"`;
then
echo "OK - Outlook Plugin Startup string matched"
exit 0
else
echo "CRITICAL - Outlook Plugin Startup string not found"
exit 2
fi
