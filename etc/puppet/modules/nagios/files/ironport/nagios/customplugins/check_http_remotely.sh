#!/usr/local/bin/bash
#==============================================================================
# check_http_remotely.sh
#
# Checks to see whether a remote host is able to access a given url,
# using specified client: nc, fetch, wget, or curl.
#
# Note that nc only tries to connect to the given port. It's fast when the
# port is alive, but uses system default timeout on connect, so can be slow if
# the remote host/port isn't alive. I've found the output from wget to be
# most useful on error (compact and informative).
#
# 2011-06-21 jramache
#==============================================================================
STATE_OK=0
STATE_WARN=1
STATE_CRIT=2
STATE_UNKN=3
EXIT_CODE=${STATE_UNKN}
INFO="Invalid script parameters"

USAGE="${0} <hostname> <nc|fetch|wget|curl> <remotehost> <uri> <port> <timeout>"

if [ ${#} -lt 6 ]; then
    echo "${INFO}"
    echo "${USAGE}"
    exit ${EXIT_CODE}
fi

HOST="${1}"
METHOD="${2}"
REMOTE_HOST="${3}"
URI="${4}"
PORT="${5}"
TIMEOUT="${6}"

case "${PORT}" in
    "80" ) HOST_URL="http://${REMOTE_HOST}${URI}" ;;
    "443") HOST_URL="https://${REMOTE_HOST}${URI}" ;;
    *    ) HOST_URL="http://${REMOTE_HOST}:${PORT}${URI}" ;;
esac

case "${METHOD}" in
    "nc"    ) GET_CMD="nc -v -w${TIMEOUT} -z ${REMOTE_HOST} ${PORT}" ;;
    "fetch" ) GET_CMD="fetch -T${TIMEOUT} -q -o /dev/null ${HOST_URL}" ;;
    "wget"  ) GET_CMD="wget --tries=1 --no-check-certificate --timeout=${TIMEOUT} -O /dev/null ${HOST_URL}" ;;
    "curl"  ) GET_CMD="curl -v -k -m${TIMEOUT} -s -o /dev/null ${HOST_URL}" ;;
    *       ) GET_CMD="" ;;
esac

if [ "${METHOD}" = "nc" ]; then
    METHOD_INFO="connect to"
else
    METHOD_INFO="retrieve"
fi

if [ "${GET_CMD}" = "" ]; then
    echo "${INFO}"
    echo "${USAGE}"
    exit ${EXIT_CODE}
fi

RESULT=`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOST} "out=\\\`${GET_CMD} 2>&1\\\`; echo \"\\\$? \\\$out\""`
RESULT_EXIT=`echo "${RESULT}" | head -1 | awk '{print $1}' | bc`
if [ ${RESULT_EXIT} -ne 0 ]; then
    RESULT_INFO=`echo "${RESULT}" | sed -e 's/^[0-9]* //' -e 's/|/--/g'`
    if [ "${RESULT_INFO}" != "" ]; then
        INFO="`printf \"CRITICAL - Unable to ${METHOD_INFO} %s (via ${METHOD})\n%s\" \"${HOST_URL}\" \"${RESULT_INFO}\"`"
    else
        INFO="CRITICAL - Unable to ${METHOD_INFO} ${HOST_URL} (via ${METHOD})"
    fi
    EXIT_CODE=${STATE_CRIT}
else
    INFO="OK - Able to ${METHOD_INFO} ${HOST_URL} (via ${METHOD})"
    EXIT_CODE=${STATE_OK}
fi

echo "${INFO}"
exit ${EXIT_CODE}
