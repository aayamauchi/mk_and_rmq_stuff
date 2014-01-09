#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

if [[ "$2" == "" ]]
then
    echo "$0 <community> <device>"
    exit 3
fi

FAULTS=`snmpwalk -OQv -v2c -c $1 $2 .1.3.6.1.4.1.9.9.719.1.1.1.1.11 2>&1`
if [ $? -ne 0 ]
then
    echo Error collecting data.  Potential SNMP or Network issue.
    printf "%b" "$FAULTS\n"
    exit 3
fi
SEVERITY=`snmpwalk -OQv -v2c -c $1 $2 .1.3.6.1.4.1.9.9.719.1.1.1.1.20`
TIME=`snmpwalk -OQv -v2c -c $1 $2 .1.3.6.1.4.1.9.9.719.1.1.1.1.14`
TYPE=`snmpwalk -OQv -v2c -c $1 $2 .1.3.6.1.4.1.9.9.719.1.1.1.1.22`
ACK=`snmpwalk -OQv -v2c -c $1 $2 .1.3.6.1.4.1.9.9.719.1.1.1.1.6`

x=1

IFS=$'\n'

SEV[0]=cleared
SEV[1]=info
SEV[2]=undef
SEV[3]=warning
SEV[4]=minor
SEV[5]=major
SEV[6]=critical

TYP[1]=fsm
TYP[2]=equipment
TYP[3]=server
TYP[4]=configuration
TYP[5]=environmental
TYP[6]=management
TYP[7]=connectivity
TYP[8]=network
TYP[9]=operational


CRIT=""
WARNf=""
WARN=""
UNKN=""
OK=""

for fault in ${FAULTS}
do
    fault=`echo ${fault} | tr -d \"`
    if [ "${fault}" == "" ]
    then
        x=`expr $x + 1`
        continue
    fi
    severity=`echo ${SEVERITY} | cut -f $x -d\ `
    time=`printf "%b" "${TIME}" | sed -n ${x}p | tr -d \"`
    let year=0x`echo $time | cut -f1,2 -d\ | tr -d \ `
    let month=0x`echo $time | cut -f3 -d\ | tr -d \ `
    let day=0x`echo $time | cut -f4 -d\ | tr -d \ `
    let hour=0x`echo $time | cut -f5 -d\ | tr -d \ `
    let minutes=0x`echo $time | cut -f6 -d\ | tr -d \ `

    type=`printf "%b" "${TYPE}" | sed -n ${x}p`
    ack=`printf "%b" "${ACK}" | sed -n ${x}p`
    
    # Downgrade port activation errors to warning per PlatOps request
    # Downgrade management services are unresponsive to warning per PlatOps request
    if [[ "$fault" == *"ETH_PORT_ACTIVATION_PKG"* ]] || \
        [[ "$fault" == *"management services are unresponsive"* ]] || \
        [[ "$fault" == *"HA functionality not ready"* ]]
    then
        severity=3
    fi
    ret="[${SEV[$severity]}] [${TYP[${type}]}] $year-$month-$day $hour:$minutes:: $fault"

    if [ $ack -eq 1 ]; then
        OK=`printf "%s" "ACKed ${ret}\n${OK}"`
    elif [ $severity -eq 6 ]; then
        CRIT=`printf "%s" "${ret}\n${CRIT}\n"`
    elif [ $severity -eq 5 ]; then
        CRIT=`printf "%s" "${CRIT}${ret}\n"`
    elif [ $severity -eq 4 ]; then
        WARNf=`printf "%s" "${ret}\n${WARNf}"`
    elif [ $severity -eq 3 ]; then
        WARN=`printf "%s" "${ret}\n${WARN}"`
    elif [ $severity -eq 2 ]; then
        UNKN=`printf "%s" "${UNKN}${ret}\n"`
    elif [ $severity -eq 1 ]; then
        WARN=`printf "%s" "${WARN}${ret}\n"`
    else
        OK=`printf "%s" "${OK}${ret}\n"`
    fi
    x=`expr $x + 1`
done

printf "%b" "`printf "%s" "${CRIT}\n${UNKN}\n${WARNf}\n${WARN}\n${OK}" | cut -b 1-4000`" | grep -v '^$'

if [ "${CRIT}" != "" ]; then
    exit=2
elif [ "${UNKN}" != "" ]; then
    exit=3
elif [ "${WARN}${WARNf}" != "" ]; then
    exit=1
else
    exit=0
fi

exit ${exit}
