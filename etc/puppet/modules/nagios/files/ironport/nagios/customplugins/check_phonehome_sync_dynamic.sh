#/bin/env bash

# Script to check if data is synced up between all SBNP app hosts
# Host are grabbed from ASDB based on user input
# Created by Iurii Prokulevych <iuprokul@cisco.com>

VERBOSE=0

# Pre-defined exit codes
EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNK=3

usage() {
   cat << EOF
   USAGE: $(basename $0) -P <product> -E <environment> -p <purpose> -v <verbosity>
   Options:
       -P product name in ASDB
       -E environment (prod/stage/dev)
       -p purpose (app/www/dbm/...)
       -v verbosity ON/OFF (default: OFF)
EOF
}

while getopts P:E:p:vh ARGS
do
    case $ARGS in
        P) PRODUCT="$OPTARG"
        ;;
        E) ENVIRONMENT="$OPTARG"
        ;;
        p) PURPOSE="$OPTARG"
        ;;
        v) VERBOSE=1
        ;;
        h) usage
           exit $EXIT_UNK
        ;;
        *) echo "UNKNOWN variable"
           exit $EXIT_UNK
        ;;
    esac
done

# Input validation
for arg in PRODUCT ENVIRONMENT PURPOSE
do
    if [ -z ${!arg} ]
    then
       echo "CRITICAL. Missed Required option \"$arg\""
       usage
       exit $EXIT_CRIT
    fi
done



if [[ $VERBOSE -ne 0 ]]
then
    echo "Grabbing hosts from ASDB"
fi

BNP_PROD_APP=`curl -s "http://asdb.ironport.com/servers/list/?product__name=${PRODUCT}&environment__name=${ENVIRONMENT}&purpose__name=${PURPOSE}"`

if [[ -z ${BNP_PROD_APP} ]]
then
    echo "UNKNOWN. No hosts found/retrieved from ASDB."
    exit $EXIT_UNK
fi

# Calculating amount of found hosts
# as separator space is used. That's why adding +1 to the grep'ed value
HOSTS=$(echo $BNP_PROD_APP | grep -o ' ' | wc -l)
let HOSTS=$HOSTS+1

EMPTY_RESPONSES=""

declare -a RESULTS=()
for i in $BNP_PROD_APP
do
   if [[ $VERBOSE -ne 0 ]]
   then
        echo "Expediting ${i}"
   fi

   RESPONSE=$(echo $(curl -kd data=li2e32:940289309bffa4c6bfea274b33f94ea3i2ee https://${i}/ 2> /dev/null))
   if [ -z "${RESPONSE}" ]
   then
        EMPTY_RESPONSES="${EMPTY_RESPONSES}Problem retrieving data from ${i}\n"
   fi
   RESULTS=("${RESULTS[@]}" "${RESPONSE}")

done

START=0               #Used for sequence generating
SIZE=${#RESULTS[@]}

if [[ ${SIZE} -eq 0 ]]
then
    echo "UNKNOWN. No data in the list."
    exit $EXIT_UNK
fi

if [ -n "${EMPTY_RESPONSES}" ]
then
    echo "CRITICAL. Problem during data retrieving"
    echo -e "${EMPTY_RESPONSES}" | sed '/^$/d'
    exit $EXIT_CRIT
fi

let END=$SIZE-1         # Used for sequence generating
STANDARD=${RESULTS[0]}  # We would compare 1st list element against all retrieved

for i in $(seq -s ' ' ${START} ${END})
do
    if [[ ${VERBOSE} -ne 0 ]]
    then
        echo ">>> DEBUG : ${STANDARD} is checked against element #${i} ${RESULTS[$i]}"
    fi

    if [ "${STANDARD}" != "${RESULTS[$i]}" ]
    then
        echo "CRITICAL. Phonehome servers' data is out of sync"
        exit $EXIT_CRIT
    fi
done
echo "OK - Phonehome servers' data is in sync"
exit $EXIT_OK
