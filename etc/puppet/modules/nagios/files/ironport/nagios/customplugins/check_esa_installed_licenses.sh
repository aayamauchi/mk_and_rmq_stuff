#!/bin/env bash

# Wrapper Script for monitoring installed licences at ESA/SMA
# And checking ther expiration date.
# Created : iuprokul@cisco.com

PLUGIN="/usr/local/ironport/nagios/customplugins/check_snmp_mga_license.py"

EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNK=3

# Defining storate for CRITICAL, WARNING, UNKOWN, OK licences
CRIT_LICENSE=""
WARN_LICENSE=""
UNK_LICENSE=""
OK_LICENSE=""

usage() {
    cat << EOF
    USAGE: $(basename $0) -H <hostname> -C <snmp community> [-x license name] -w <warning threshold> -c <critical threshold> [-v verbosity] -h <help>
    Required Options:
    -H Hostname
    -C community
    -x exclude license
    -w Warning threshold
    -c Critical threshold
    -h Display this help message and exit
    -v verbose output. Useful for manual debugging.


    check_esa_installed_licenses.sh -H prod-cres-esa1.vega.ironport.com -C '****' -w 2592000 -c 604800 - check all licenses

    check_esa_installed_licenses.sh -H prod-cres-esa1.vega.ironport.com -C '****' -x 'McAfee' -w 2592000 -c 604800  -- all except 'McAfee'
    check_esa_installed_licenses.sh -H prod-cres-esa1.vega.ironport.com -x 'McAfee\|IronPort\ Anti-Spam' -C '****' -w 2592000 -c 604800 -- excluded two licenses
EOF
}

# Printing output
function print_licenses() {
    for i in CRIT_LICENSE WARN_LICENSE UNK_LICENSE OK_LICENSE
    do
        if [[ -z "${!i}" ]]
        then
            echo "No Licences in $(echo ${i} | cut -d"_" -f1) State"
        else
            echo -e "Licenses in ${i}\n-------------------------\n$(echo ${!i} | tr ':' '\n')"
            echo "-------------------------"
        fi
    done
}

HOST=""
COMMUNITY=""
EXCLUDE=""
WARN=""
CRIT=""
VERBOSE=0

while getopts hH:C:x:w:c:v ARGS
do
    case $ARGS in
        H) HOST="$OPTARG"
        ;;
        C) COMMUNITY="$OPTARG"
        ;;
        x) EXCLUDE="$OPTARG"
        ;;
        w) WARN="$OPTARG"
        ;;
        c) CRIT="$OPTARG"
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

for reqopt in HOST COMMUNITY WARN CRIT
do
    if [ -z ${!reqopt} ]
    then
        echo -e "$reqopt MUST be specified\n"
        usage
        exit $EXIT_UNK
    fi
done

# Firstly, trying to see if valid data where returned
EXEC_OUTPUT=$(${PLUGIN} -H $HOST -s $COMMUNITY)
echo "${EXEC_OUTPUT}" | grep -iq 'no data'
OUT_STATE=$?

if [[ $OUT_STATE -eq 0 ]]
then
   echo "UNKNOWN. $EXEC_OUTPUT"
   exit $EXIT_UNK
fi

if [ -z "$EXCLUDE" ]; then
    LICENSES=$(${PLUGIN} -H $HOST -s $COMMUNITY | grep -vi "installed" | tr ' ' ':')
else
    LICENSES=$(${PLUGIN} -H $HOST -s $COMMUNITY | grep -vi "installed" | grep -vi "$EXCLUDE" | tr ' ' ':')
fi

for license in $LICENSES 
do
    license=$(echo "$license" | tr ":" ' ')
    [[ $VERBOSE -gt 0 ]] && {
        echo "--> Checking :: $license"
    }

    ${PLUGIN} -H $HOST -s $COMMUNITY -l"${license}" -w $WARN -c $CRIT > /dev/null
    STATE_EXEC=$?
    [[ $verbose -gt 0 ]] && {
        echo $OUTPUT
    }

    case $STATE_EXEC in
        0) OK_LICENSE="$OK_LICENSE:$license"
        ;;
        1) WARN_LICENSE="$WARN_LICENSE:$license"
        ;;
        2) CRIT_LICENSE="$CRIT_LICENSE:$license"
        ;;
        *) UNK_LICENSE="$UNK_LICENSE:$license"
        ;;
    esac
done

# Removing whitespaces and colons
OK_LICENSE=$(echo $OK_LICENSE | sed -e 's/^[ \t:]*//')
WARN_LICENSE=$(echo $WARN_LICENSE | sed -e 's/^[ \t:]*//')
CRIT_LICENSE=$(echo $CRIT_LICENSE | sed -e 's/^[ \t:]*//')
UNK_LICENSE=$(echo $UNK_LICENSE | sed -e 's/^[ \t:]*//')

# Calculating Amount of "BAD" licenses
for ARG in OK_LICENSE WARN_LICENSE CRIT_LICENSE UNK_LICENSE
do
    case $ARG in
        "OK_LICENSE" ) [ "${!ARG}" != "" ] &&
                      {
                      OK_AMOUNT=$( echo $(echo ${!ARG} | grep -o ':' | wc -l ) +1 | bc )
                      } ||
                      OK_AMOUNT=0
        ;;
        "WARN_LICENSE") [ "${!ARG}" != "" ] &&
                       {
                        WARN_AMOUNT=$( echo $(echo ${!ARG} | grep -o ':' | wc -l ) +1 | bc )
                       } ||
                        WARN_AMOUNT=0
        ;;
        "CRIT_LICENSE") [ "${!ARG}" != "" ] &&
                       {
                        CRIT_AMOUNT=$( echo $(echo ${!ARG} | grep -o ':' | wc -l ) +1 | bc )
                       } ||
                        CRIT_AMOUNT=0
        ;;
        *) [ "${!ARG}" != "" ] &&
          {
           UNK_AMOUNT=$( echo $(echo ${!ARG} | grep -o ':' | wc -l ) +1 | bc )
          } ||
           UNK_AMOUNT=0
        ;;
    esac

done

[[ $verbose -gt 0 ]] && {
    echo "-------DEBUG-------"
    echo "OK LICENCES Amount :: $OK_AMOUNT "
    echo $OK_LICENSE | tr ':' '\n'
    echo "WARNING LICENSE :: $WARN_AMOUNT"
    echo $WARN_LICENSE | tr ':' '\n'
    echo "CRITICAL LICENSE :: $CRIT_AMOUNT"
    echo $CRIT_LICENSE | tr ':' '\n'
    echo "UNKNOWN LICENSE :: $UNK_AMOUNT"
    echo $UNK_LICENSE | tr ':' '\n'
    echo "-------DEBUG-------"
}

# Evaluating and Formatting output
# If even 1 licence is CRITICAL -- EXIT_CRIT
# If even 1 license is WARNING and no CRITICALS -- EXIT_WARN
# If even 1 licence UNKNOWN and no WARNING and CRITICAL -- EXIT_UNK
# Else -- EXIT_OK

if [[ -n "${CRIT_LICENSE}" ]]
then
    echo "CRITICAL. Please check ${CRIT_AMOUNT} licence(s)"
    print_licenses
    exit $EXIT_CRIT
fi

if [[ -n "${WARN_LICENSE}" ]]
then
    echo "WARNING. Please check ${WARN_AMOUNT} license(s)"
    print_licenses
    exit $EXIT_WARN
fi

if [[ -n "${UNK_LICENSE}" ]]
then
    echo "UNKNOWN. Please check ${UNK_AMOUNT} license(s)"
    print_licenses
    exit $EXIT_UNK
fi

# OK Event :)
echo -e "OK. All installed licences are within thresholds"
echo -e "OK License:\n-------------------------\n$(echo ${OK_LICENSE} | tr ':' '\n')"
exit $EXIT_OK
