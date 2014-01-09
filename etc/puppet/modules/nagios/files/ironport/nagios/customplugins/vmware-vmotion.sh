#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/usr/local/ironport/nagios/customplugins

USER=$1
PASS=$2
VM=$3
OLD=$4
LIST=`check_esx3.pl -H ${OLD} -u ${USER} -p ${PASS} -l runtime -s list 2>/dev/null`

if [[ "${LIST}" == *"${VM}"* ]]
then
    echo "Active on '${OLD}'"
    exit 0

else
    echo "No longer active on '${OLD}'"
    echo "VMotion event or Image deletion has occurred."
    exit 2
fi

