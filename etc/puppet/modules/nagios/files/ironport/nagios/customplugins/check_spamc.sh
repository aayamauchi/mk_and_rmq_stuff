#!/usr/local/bin/bash
#==============================================================================
# check_spamc.sh
#
# Quick fix for MONOPS-454
#
# If this is used for more than anything temporary, it should be
# modified to do proper option argument parsing and allow for a port
# number to be passed in as well (defaults to 783 now)
#
# 2011-11-18 jramache
#==============================================================================
HOSTNAME="${1}"

CMD="echo test | spamc -x  >/dev/null 2>&1"
RESULT=`/usr/bin/ssh -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa nagios@${HOSTNAME} "${CMD}; echo \\${?}" 2>/dev/null`

if [ ${RESULT} -eq ${RESULT} ] 2>/dev/null; then
    if [ ${RESULT} -gt 60 ]; then
        # exit codes for spamc 3.3.2
        case ${RESULT} in
            64) INFO="command line usage error";;
            65) INFO="data format error";;
            66) INFO="cannot open input";;
            67) INFO="addressee unknown";;
            68) INFO="host name unknown";;
            69) INFO="service unavailable";;
            70) INFO="internal software error";;
            71) INFO="system error (e.g., can't fork)";;
            72) INFO="critical OS file missing";;
            73) INFO="can't create (user) output file";;
            74) INFO="input/output error";;
            75) INFO="temp failure; user is invited to retry";;
            76) INFO="remote error in protocol";;
            77) INFO="permission denied";;
            78) INFO="configuration error";;
            98) INFO="message was too big to process (see --max-size)";;
             *) INFO="unknown exit code returned: ${RESULT}";;
        esac
        echo "CRITICAL - ${INFO} (exit code: ${RESULT})"
        exit 2
    fi
else
    echo "CRITICAL - non-numeric exit code returned from spamc check"
    exit 2
fi

echo "OK - all fine"
exit 0
