#!/usr/local/bin/bash

maildir="/usr/local/ironport/nagios/mail/Sysops_Alert"

PATH=/bin:/usr/bin:/usr/local/bin
A=`sudo -u nagios ls -A $maildir/new/`

if [ "${A}" == "" ]
then
    echo No pages to clear.
else
    echo Clearing manual pages.
    for f in $A
    do
        f="$maildir/new/$f"
        sudo -u nagios grep "^From" $f
        sudo -u nagios grep "^Subject" $f
        sudo -u nagios mv $f $maildir/cur/
    done
fi

