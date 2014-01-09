#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

# Check health of puppet via log parsing.  Tie to a puppet_run event handler.
# Take optional argument for maximum seconds since puppet run.

HOST=$1
MAXA=$2
SSHARG="-o ConnectTimeout=2 -o ConnectionAttempts=2"

if [ "$HOST" == "" ]
then
    echo "$0 <hostname> [<max age in seconds>]"
    exit 3
fi

AGE=`ssh $SSHARG nagios@$HOST "stat -c %Y /var/log/puppet/puppet.log 2>/dev/null" 2>/dev/null`
if [ $? -ne 0 ]
then
    OS=`ssh $SSHARG nagios@$HOST "uname" 2>/dev/null`
    if [ "$OS" == "" ]
    then
        echo Error connecting to $HOST
        exit 3
    elif [ "$OS" != "Linux" ]
    then
        echo Puppet not supported on \'$OS\'
        exit 0
    else
        echo Unhandled error.  Puppet might not be installed.  Exiting OK
        exit 0
    fi
fi

if [ "$AGE" == "" ]
then
    echo "Error collecting seconds since last puppet run."
    exit 3
fi
NOW=`date +%s`
AGE=`echo $NOW - $AGE | bc`

FAIL=`ssh nagios@$HOST "tail -8 /var/log/puppet/puppet.log | grep -i fail > /dev/null; echo $?" 2>/dev/null`
if [ $FAIL -ne 0 ]
then
    echo "Last Puppet run failed.  Run was $AGE seconds ago."
    exit 2
fi

if [ "$MAXA" != "" ]
then
    if [ $AGE -ge $MAXA ]
    then
        echo "Last Puppet run was $AGE seconds ago."
        exit 2

    fi
fi

echo "Puppet healthy.  Last run $AGE seconds ago."
exit 0
