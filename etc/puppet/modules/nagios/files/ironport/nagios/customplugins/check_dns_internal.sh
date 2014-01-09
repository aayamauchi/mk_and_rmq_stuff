#!/bin/sh
# MONOPS-927

NAGIOS_HOSTADDRESS="$1"
URL="$2"
WARN_VALUE="$3" # DNS reply size limit is at least, value <= 1400

CRIT_VALUE="$3" # lacks EDNS
CRIT_VALUE_DEFAULT="lacks EDNS"

# exit codes, see http://nagiosplug.sourceforge.net/developer-guidelines.html
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2
EXIT_UNKNOWN=3
EXIT_CODE=$EXIT_UNKNOWN


usage () {
    echo "Check for internal dns servers, see MONOPS-927 for details."
    echo "Usage: $0 <RDNS host> <URL> <WARNING VALUE> [CRITICAL VALUE]"
    echo "Where:"
    echo " URL is hostname (i.e. rs.dns-oarc.net )"
    echo " WARNING VALUE is a DNS reply size limit, in bytes"
    echo " CRITICAL VALUE -- \"a No EDNS answer\", default is \"lacks EDNS\" "
    exit $EXIT_UNKNOWN
}

set -u

#validate parameters and options
[ -z "$URL" -o -z "$NAGIOS_HOSTADDRESS" ] && usage
[ ! -z "${WARN_VALUE##*[!0-9]*}" ] || {
    echo "WARN_VALUE is not a number."
    usage
}

[ -z "$CRIT_VALUE" ] && CRIT_VALUE="$CRIT_VALUE_DEFAULT"


compare_two_digits () {
    local a="$1"
    local b="$2"
    result=$(echo "a=$a;b=$b;r=2;if(a==b)r=0;if(a>b)r=1;r"|bc)
    # 0 - are equal, 1 -- a is bigger then b, 2 -- a is less then b
    return $result
}

EDNS_ANSWER=`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${NAGIOS_HOSTADDRESS} \
    "dig +short \"$URL\" txt | grep -v 'sent EDNS ' | grep 'DNS'"`
EDNS_ANSWER=`echo "$EDNS_ANSWER" | sed 's/["]//g'`


[ -z "$EDNS_ANSWER" ] && {
    echo "Empty answer: \"$EDNS_ANSWER\""
    exit "$EXIT_CRITICAL" # no answer
}

echo "$EDNS_ANSWER" | grep -q "$CRIT_VALUE"  && {
    echo "$EDNS_ANSWER" # the following result comes from a DSL router that does not support EDNS
    exit "$EXIT_CRITICAL" 
}

ACTUAL_VALUE=$(echo "$EDNS_ANSWER" | sed 's [^least]*[^0-9]*\([0-9]*\).* \1 ') 


compare_two_digits "$WARN_VALUE" $ACTUAL_VALUE 
case $? in
    1) EXIT_CODE=$EXIT_WARNING
    ;;
    *) EXIT_CODE=$EXIT_OK 
    ;;
esac

echo \"$EDNS_ANSWER\"
exit $EXIT_CODE

