#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/bin
HOST=`echo $1 | tr -d \$`
OS=`echo $2 | tr -d \$ | tr '[A-Z]' '[a-z]'`
FILE=/usr/local/nagios/www/nagios/audit/${HOST}.html
NOW=`date +%s`
SSHARGS='-q -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=2'
OUT=''
STAT=`hostname`

HEAD="<html><head><title>${HOST}</title></head><body><pre>"
TAIL="</pre></body></html>"

if [ "${HOST}" == "" ]
then
    echo "No host passed."
    exit 2
fi

if [[ ! -e ${FILE} ]] || [[ `stat -f %m ${FILE}` -lt `echo ${NOW} - 300 | bc` ]]
then
    if [ "${OS}" == "" ]
    then
        OS=`nagiosstatc -q "object host ${HOST} _OS" -p -s ${STAT} | grep _OS | cut -d\' -f 4 | tr '[A-Z]' '[a-z]'`
    fi

    echo "[`date`] ${HOST} '${OS}'" >> /tmp/host-audit.out

    if [[ "${OS}" == *freebsd* ]] || [[ "${OS}" == *linux* ]]
    then
        HEAD="${HEAD}
        <a href=#netstat>netstat</a>
        <a href=#vmstat>vmstat</a>
        <a href=#iostat>iostat</a>
        <a href=#dmesg>dmesg</a>
        <a href=#ps>ps</a>
        <a href=#sysctl>sysctl</a>
        <a href=#mount>mount</a>
        <a href=#df>df</a>"

        OUT=`/usr/local/ironport/nagios/customplugins/timeout.pl -9 20 ssh -i ~nagios/.ssh/id_rsa ${SSHARGS} nagios@$1 "
        date
        echo '<hr><b>uptime</b><br>'
        uptime
        echo '<hr><div id=netstat><b>netstat -an</b><br>'
        netstat -an
        echo '<hr><div id=vmstat><b>vmstat</b><br>'
        vmstat
        echo '<hr><div id=iostat><b>iostat 1 5</b><br>'
        iostat 1 5
        echo '<hr><div id=dmesg><b>dmesg</b><br>'
        dmesg | sed -e 's/\</\&lt;/g' -e 's/\>/\&gt;/g'
        echo '<hr><div id=ps><b>ps auxww</b><br>'
        ps auxww | grep -v echo | sed -e 's/\</\&lt;/g' -e 's/\>/\&gt;/g'
        echo '<hr><div id=sysctl><b>sysctl -A</b><br>'
        sysctl -A | sed -e 's/\</\&lt;/g' -e 's/\>/\&gt;/g'
        echo '<hr><div id=mount><b>mount</b><br>'
        mount
        echo '<hr><div id=df><b>df -l</b><br>'
        df -l" 2>&1`

        EXIT=$?

    elif [[ "${OS}" == *asyncos* ]]
    then
        HEAD="${HEAD}
        <pre>"

        USER=`nagiosstatc -q "object host ${HOST} __ASYNC_USER" -p -s ${STAT} | grep _USER | cut -d\' -f 4`
        PASS=`nagiosstatc -q "object host ${HOST} __ASYNC_PASS" -p -s ${STAT} | grep _PASS | cut -d\' -f 4`
        OUT=`asyncos_audit.py "${HOST}" "${USER}" "${PASS}"`
        EXIT=$?

    else
        OUT="Apologies but we do not currently offer a host audit for this OS.<br><b>${OS}</b><br>"
        EXIT=3
    fi
fi

if [[ "${EXIT}" == "0" ]]
then
    printf "%b" "${HEAD}\n${OUT}\n${TAIL}" > ${FILE}
else
    printf "%b" "${OUT}\n" > ${FILE}.err
fi
