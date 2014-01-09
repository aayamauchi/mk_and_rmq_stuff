#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

HOST=$1
CRIT=$2
RSA=`echo ~nagios`/.ssh/id_rsa
SSHCMD="ssh -o StrictHostKeyChecking=no -i ${RSA} nagios@${HOST}"
NAG=/usr/local/nagios

OUT=`${SSHCMD} 'cat /usr/local/nagios/var/ocsp.status
echo
x=\`uname\`
if [ "\$x" == "Linux" ]
then
    stat -c %Y /usr/local/nagios/var/tmp/send_nsca.cache
else
    stat -L -f %m /usr/local/nagios/var/tmp/send_nsca.cache
fi' 2>/dev/null`

STATE=`printf "%s" "${OUT}" | head -1`
AGE=`echo \`date +%s\` - \`printf "%s" "${OUT}" | tail -1\` | bc`

if [ "${STATE}" == "" ]
then
    echo Data collection error, no State.
    exit 3
elif [ "${AGE}" == "" ]
then
    echo Data collection error, no Age.
    exit 3
fi

if [[ "${STATE}" == "0" ]] && [[ ${AGE} -lt ${CRIT} ]]
then
    echo NSCA Caching system functional, cache ${AGE}s old.
else
    echo NSCA Caching system error, cache age ${AGE}s\; state ${STATE}
    ${SSHCMD} "/usr/local/nagios/bin/send_nsca -h | head -2
    /usr/local/nagios/bin/nsca -h | head -4
    echo
    ls -l /usr/local/nagios/var/ocsp.status
    ls -l /usr/local/nagios/var/tmp/send_nsca.cache"
    exit 2
fi
