#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

for x in `grep host_name /usr/local/nagios/etc/hosts/*cfg | awk '{ print $3 }' | sort | uniq`

do 
    sshout=`ssh -o NumberOfPasswordPrompts=0 -o ConnectTimeout=1 $x "exit" 2>&1`
    if [[ "${sshout}" =~ "ffending" ]]
    then
        echo $x
        line=`printf "%b" "${sshout}" | grep ffending`
        # Offending key for IP in /usr/local/var/nagios/.ssh/known_hosts:755
        # Offending key in /usr/local/var/nagios/.ssh/known_hosts:190
        file=`echo $line | rev | awk '{ print $1 }' | rev | tr -d '\r'`
        line=`echo $file | awk -F: '{ print $2 }'`
        file=`echo $file | awk -F: '{ print $1 }'`
        echo "Removing line #${line} from ${file}"
        sed -in "${line}d" ${file}
        ssh -o NumberOfPasswordPrompts=0 -o ConnectTimeout=1 $x "exit" 2>&1
    fi
done
