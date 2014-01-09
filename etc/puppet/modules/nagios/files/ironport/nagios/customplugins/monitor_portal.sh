#!/usr/local/bin/bash
PATH=/bin:/usr/bin:/usr/local/bin

CURL="curl"
GREP="grep"
ECHO="echo"
SED="sed"
DATE="date"
EXPR="expr"

# Step through and get values for command line arguments
# echo usage if incorrect argument found
while [ $# -gt 0 ]; do
    case "$1" in
    -H)  hostname="$2"; shift;;
    -c)  critical_time="$2"; shift;;
    -*)
        ${ECHO} >&2 \
        "usage: $0 -H hostname"
        exit 1;;
    *)  break;; # terminate while loop
    esac
    shift
done

# Exit if user did not define a hostname
if [ x${hostname} = x ]; then
    ${ECHO} "You must specify a host to check! USAGE: $0 -H hostname"
    exit 1
fi

# Get hostname into correct format - either "app1" or "app2"
host=`${ECHO} ${hostname} | ${SED} 's/.soma.ironport.com//'`
host=`${ECHO} ${host} | ${SED} 's/sso-//'`

starttime=`${DATE} +%s`

${CURL} -k -d 'emailid=monitor%40test.org&password=m0niToR&task=login&submit=Login' \
   https://${hostname}/irppcnctr/login 2>/dev/null | ${GREP} 'Welcome Automated Monitor' >/dev/null 2>&1

if [ $? -ne 0 ]; then
  exit_status=2
  exit_message="CRITICAL - unable to login to portal on ${hostname}."
else
  exit_status=0
  exit_message="OK - can log in to portal on ${hostname}."
fi

endtime=`${DATE} +%s`

# check login time
time=`${EXPR} ${endtime} - ${starttime}`

if [ ${time} -gt ${critical_time:=60} ]; then
  exit_status=2
  exit_message="CRITCAL - Portal login time ${time} seconds on ${hostname}."
fi

${ECHO} "$exit_message"
exit $exit_status
