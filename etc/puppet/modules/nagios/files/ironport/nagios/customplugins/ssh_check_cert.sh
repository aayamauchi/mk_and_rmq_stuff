#!/bin/bash

EXIT_OK=0
EXIT_WARNING=1
EXIT_CRIT=2
EXIT_UNK=3

USAGE=$( cat << EOM
Usage: `basename ${0}` -H hostname -u nagios -f path_to_certificate -z cert_type -c days -w days [-h]
	-H|--host      Hostname
	-u|--user      User
	-f|--certpath  Full path with certificate filename
	-z|--certtype  Type of certificate: crl and ca currently
	-c|--critical  Critical number of days left till expiration
	-w|--warning   Warning number of days left till expiration
	-h|--help      Help
EOM
)


while [ $# -gt 0 ]; do
    case "$1" in
    -H|--host)      hostname="$2"; shift;;
    -u|--user)      user="$2"; shift;;
    -f|--certpath)  certpath="$2"; shift;;
    -w|--warning)   warning="$2"; shift;;
    -c|--critical)  critical="$2"; shift;;
    -z|--certtype)  certtype="$2"; shift;;
    -h|--help)  echo "${USAGE}"; exit $EXIT_UNK;;
    --) shift; break;;
    *)  echo "${USAGE}"; exit $EXIT_UNK;; # terminate while loop
    esac
    shift
done

if [[ -z ${critical} || -z ${warning} || -z ${hostname} || -z ${certpath} || -z ${user} ]]; then
	echo "${USAGE}"
	exit $EXIT_UNK
fi

if [[ ${certtype} == 'crl' ]]; then
	nextupdate=`ssh ${user}@${hostname} "test -e ${certpath} && openssl crl -nextupdate -in ${certpath}|grep nextUpdate"`
elif [[ ${certtype} == 'ca' ]]; then
	nextupdate=`ssh ${user}@${hostname} "test -e ${certpath} && openssl x509 -text -noout -in ${certpath}|grep 'Not After'"`
else
	echo "Please provide valid certtype"
	exit $EXIT_UNK
fi

if [[ -z ${nextupdate} ]]; then
	echo "No certificate data received"
	exit $EXIT_CRIT
fi

if [[ ${certtype} == 'crl' ]]; then
	nextupdate_epoch=`date -d "$(echo $nextupdate|awk -F '=' '{print $2}')" +%s`
elif [[ ${certtype} == 'ca' ]]; then
	nextupdate_epoch=`date -d "$(echo $nextupdate|awk -F ' : ' '{print $2}')" +%s`
fi

now=`date +%s`
certname=`echo ${certpath} |awk -F '/' '{print $NF}'`
let valid_sec=${nextupdate_epoch}-${now}
let valid_days=${valid_sec}/86400

if [[ "$valid_days" -lt "$critical" ]]; then
	echo "CRITICAL - $certname will expire in $valid_days days, critical threshold is $critical days"
	exit $EXIT_CRIT
elif [[ "$valid_days" -lt "$warning" ]]; then
	echo "WARNING - $certname will expire in $valid_days days, warning threshold is $warning days"
	exit $EXIT_WARNING
else
	echo "OK - $certname valid $valid_days days"
	exit $EXIT_OK
fi




