#!/usr/bin/env bash

EXIT_OK=0
EXIT_WARNING=1
EXIT_CRIT=2
EXIT_UNK=3

user='nagios'

USAGE=$( cat << EOM
Script will check difference between numver of entries in mysql table with number of entries in csv file available over http.
NOTE: if critical,warning thresholds are not provided any deviation between will rise CRITICAL

Usage: `basename ${0}` -H hostname -p mysql_password -d db_name -q query_table -f path_to_csv [-u user] [-c critical diff] [-w warning diff] [-h]
        -H|--host      Hostname
        -u|--user      User
        -p|--password  Mysql password
        -d|--db        Mysql database
        -q|--qtable    Which mysql table to query
        -f|--feed      Feed http address
        -c|--critical  Critical number of days left till expiration
        -w|--warning   Warning number of days left till expiration
        -h|--help      Help
EOM
)


while [ $# -gt 0 ]; do
    case "$1" in
    -H|--host)      hostname="$2"; shift;;
    -u|--user)      user="$2"; shift;;
    -p|--password)  password="$2"; shift;;
    -d|--db)        db="$2"; shift;;
    -q|--qtable)    qtable="$2"; shift;;
    -f|--feed)      feed="$2"; shift;;
    -c|--critical)  critical="$2"; shift;;
    -w|--warning)   warning="$2"; shift;;
    -h|--help)  echo "${USAGE}"; exit $EXIT_UNK;;
    --) shift; break;;
    *)  echo "${USAGE}"; exit $EXIT_UNK;; # terminate while loop
    esac
    shift
done

if [[ -z ${hostname} || -z ${password} || -z ${db} || -z ${qtable} || -z ${feed} ]]; then
        echo "${USAGE}"
        exit $EXIT_UNK
fi

mysql_count=`mysql -h ${hostname} -u ${user} -p${password} -D ${db} --execute="SELECT count(*) FROM ${qtable}\G"|grep count | awk '{print $NF}'`

if [[ -z ${mysql_count} || ${mysql_count} -eq 0 ]]; then
	echo "MySQL: no such table or table empty"
	exit $EXIT_UNK
fi

check_feed=`curl -s -L -I -w "%{http_code}" ${feed} -o /dev/null`

if [[ ${check_feed} -ne '200' ]]; then
    echo "No such feed, curl returned ${check_feed} response status code"
    exit $EXIT_UNK
fi

cvs_count=`curl -s -S ${feed} 2>&1| wc -l`
difference=`echo $mysql_count - $cvs_count|bc|sed 's/-//'`

if [[ ${difference} != 0 ]]; then
	if [[ "${critical}" && ${difference} -ge ${critical} ]]; then
		echo "CRITICAL: Mysql and feed count difference is ${difference}, (critical: ${critical})"
		exit $EXIT_CRIT
	elif [[ "${warning}" && ${difference} -ge ${warning} ]]; then
		echo "WARNING: Mysql and feed count difference is ${difference}, (warning: ${warning})"
		exit $EXIT_WARNING
	elif [[ "${critical}" || "${warning}" ]]; then
		echo "OK -  Mysql and feed count diffenece is ${difference} (critical: ${critical}, warning: ${warning}) "
		exit $EXIT_OK
	fi
	echo "CRITICAL: Mysql and feed count difference is ${difference}"
	exit $EXIT_CRIT
else
	echo "OK -  Mysql and feed count is equal"
	exit $EXIT_OK
fi


#SELECT count(*) FROM `sb`.`domain_ranges_v4`;
#http://feeds.ironport.com/maxmind_domain/data/GeoIP-Domain.csv

#SELECT count(*) FROM `sb`.`location_ranges_v4`;
#http://feeds.ironport.com/maxmind/data/GeoLiteCity-Location.csv

#SELECT count(*) FROM `sb`.`organization_ranges_v4`;
#http://feeds.ironport.com/maxmind_organization/data/GeoIP-Organization.csv




