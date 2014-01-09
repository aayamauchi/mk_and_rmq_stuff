#!/usr/local/bin/bash
#========================================================================
# cert_report.sh
#
# Generates report of all certificates monitored by Nagios, containing
# each host, certificate expiration date, and nagios service check name.
# Output is formatted in Portal CSV format and copied to each of the
# ASDB servers for Portal consumption. The idea is to run this like once
# per day.
#
# Additionally, a nagios status file is output with aggregated status
# of expirations. This file is retrieved by a nagios monitor.
# This has a separate notion of thresholds than the individual cert
# monitors. It will alert more quickly, based on thresholds defined
# here in this script.
#
# For MONOPS-237
#
# 2011-12-19 jramache
#========================================================================
ASDB_SERVERS=`fetch -q -o- "https://asdb.ironport.com/servers/list/?product__name=awesome&environment__name=prod&purpose__name=app"`
DEST_DIR="/data/awesome/portal"
REPORT_FILE="/tmp/cert_audit_report.txt"
NAGIOS_FILE="/tmp/cert_audit_status.txt"

# Nagios thresholds and related variables. These are only used by the 
# aggregate report monitor.
WARNING=3888000
CRITICAL=2592000
CRITICAL_CERTS=""
WARNING_CERTS=""
UNKNOWN_CERTS=""
N_CRITICAL=0
N_WARNING=0
N_OK=0
N_UNKNOWN=0
N_TOTAL=0
NAGIOS_STATE=3

if [ "`whoami`" != "nagios" ]; then
    echo "Must run as nagios"
    exit 1
fi

ParseTime() {
    # Convert certificate expiration to unix time (seconds from epoch).
    STR_DATETIME="${1}"
    _U_TIME=
    # "%m/%d/%Y %H:%M"
    if `uname -s | grep Linux 1>/dev/null 2>/dev/null`; then
        _U_TIME=`date --date="${STR_DATETIME}" +%s 2>/dev/null`
    else
        _U_TIME=`date -j -f "%m/%d/%Y %H:%M" "${STR_DATETIME}" +%s 2>/dev/null`
    fi
}

T_NOW=`date +%s`

echo "Host_string,Product_string,Purpose_string,Portfolio_string,Certificate Expiration_stringasc,Nagios Service Check_string,row#color" > ${REPORT_FILE}
IFS_BACKUP=${IFS}
IFS="
"
for HOST_SERVICE in `python /usr/local/ironport/akeos/bin/cert_audit.py 2>/dev/null | grep -v ^#`
do
    N_TOTAL=$(( ${N_TOTAL} + 1 ))
    HOST="`echo ${HOST_SERVICE} | awk -F'\t' '{print $1}' 2>/dev/null`"
    SERVICE="`echo ${HOST_SERVICE} | awk -F'\t' '{print $2}' 2>/dev/null`"
    PRODUCT="`echo ${HOST_SERVICE} | awk -F'\t' '{print $3}' 2>/dev/null`"
    PURPOSE="`echo ${HOST_SERVICE} | awk -F'\t' '{print $4}' 2>/dev/null`"
    PORTFOLIO="`echo ${HOST_SERVICE} | awk -F'\t' '{print $5}' 2>/dev/null`"
    SOURCE_URL="`echo ${HOST_SERVICE} | awk -F'\t' '{print $6}' 2>/dev/null`"
    COMMAND=`/usr/local/ironport/nagios/bin/nagios_command.py -H \"${HOST}\" -S \"${SERVICE}\"`
    RAW_CHECK_RESULT=`eval "${COMMAND}" 2>/dev/null`
    EXIT_CODE=${?}
    case ${EXIT_CODE} in
        0 ) COLOR="";;
        1 ) COLOR="#885500";;
        2 ) COLOR="#AA0000";;
        * ) COLOR="#990099";;
    esac
    SANITIZED_CHECK_RESULT=`echo "${RAW_CHECK_RESULT}" | tr '\n' ' ' | tr ',' ';'`
    CHECK_RESULT=`echo "${RAW_CHECK_RESULT}" | grep -i expire 2>/dev/null | head -1 2>/dev/null`
    EXPIRATION=`echo "${CHECK_RESULT}" | grep -o '[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]' 2>/dev/null`

    if [ ${?} -eq 0 ]; then
        # Expected output

        # Append to portal report
        echo "${HOST},${PRODUCT},${PURPOSE},${PORTFOLIO},${EXPIRATION},<a href=\"https://mon.ops.ironport.com/nagios/cgi-bin/extinfo.cgi?type=2&host=${HOST}&service=${SERVICE}\" target=\"_blank\">${SERVICE}</a>,${COLOR}" >> ${REPORT_FILE}

        # Append to nagios output
        ParseTime "${EXPIRATION}"
        if [ ${?} -eq 0 ]; then
            T_EXP=${_U_TIME}
            T_DIFF=$(( ${T_EXP} - ${T_NOW} ))
            if [ ${T_DIFF} -lt ${CRITICAL} ]; then
                ALERT_STR="${HOST}: CRITICAL - expires ${EXPIRATION}"
                if [ ${N_CRITICAL} -gt 0 ]; then
                    CRITICAL_CERTS="${CRITICAL_CERTS}
${ALERT_STR}"
                else
                    CRITICAL_CERTS="${ALERT_STR}"
                fi
                N_CRITICAL=$(( ${N_CRITICAL} + 1 ))
            elif [ ${T_DIFF} -lt ${WARNING} ]; then
                ALERT_STR="${HOST}: WARNING - expires ${EXPIRATION}"
                if [ ${N_WARNING} -gt 0 ]; then
                    WARNING_CERTS="${WARNING_CERTS}
${ALERT_STR}"
                else
                    WARNING_CERTS="${ALERT_STR}"
                fi
                N_WARNING=$(( ${N_WARNING} + 1 ))
            else
                N_OK=$(( ${N_OK} + 1 ))
            fi
        else
            ALERT_STR="${HOST}: UNKNOWN - Unable to parse expiration time: ${EXPIRATION}"
            if [ ${N_UNKNOWN} -gt 0 ]; then
                UNKNOWN_CERTS="${UNKNOWN_CERTS}
${ALERT_STR}"
            else
                UNKNOWN_CERTS="${ALERT_STR}"
            fi
            N_UNKNOWN=$(( ${N_UNKNOWN} + 1 ))
        fi
    else
        # Unexpected output

        # Append to portal report
        echo "${HOST},${PRODUCT},${PURPOSE},${PORTFOLIO},${SANITIZED_CHECK_RESULT},<a href=\"https://mon.ops.ironport.com/nagios/cgi-bin/extinfo.cgi?type=2&host=${HOST}&service=${SERVICE}\" target=\"_blank\">${SERVICE}</a>,${COLOR}" >> ${REPORT_FILE}

        # Append to nagios output
        ALERT_STR="${HOST}: UNKNOWN - Unable to parse expiration time: ${SANITIZED_CHECK_RESULT}"
        if [ ${N_UNKNOWN} -gt 0 ]; then
            UNKNOWN_CERTS="${UNKNOWN_CERTS}
${ALERT_STR}"
        else
            UNKNOWN_CERTS="${ALERT_STR}"
        fi
        N_UNKNOWN=$(( ${N_UNKNOWN} + 1 ))
    fi

    # Play nice
    sleep 1
done

# Copy to ASDB Servers
IFS=${IFS_BACKUP}
for H in ${ASDB_SERVERS}
do
    echo "Copying to ${H}"
    /usr/bin/scp -o StrictHostKeyChecking=no -i ~nagios/.ssh/id_rsa ${REPORT_FILE} nagios@${H}:${DEST_DIR}
done

# Create nagios status file
INFO=""

NAGIOS_STATE=3
if [ ${N_CRITICAL} -gt 0 ]; then
    INFO="CRITICAL ${N_CRITICAL}/${N_TOTAL} certificates"
    if [ ${N_WARNING} -gt 0 ]; then
        INFO="${INFO}, ${N_WARNING} WARNING"
    fi
    if [ ${N_UNKNOWN} -gt 0 ]; then
        INFO="${INFO}, ${N_UNKNOWN} UNKNOWN"
    fi
    INFO="${INFO}, ${N_OK} OK
${CRITICAL_CERTS}
${WARNING_CERTS}
${UNKNOWN_CERTS}"
    NAGIOS_STATE=2
elif [ ${N_WARNING} -gt 0 ]; then
    INFO="WARNING ${N_WARNING}/${N_TOTAL} certificates"
    if [ ${N_UNKNOWN} -gt 0 ]; then
        INFO="${INFO}, ${N_UNKNOWN} UNKNOWN"
    fi
    INFO="${INFO}, ${N_OK} OK
${WARNING_CERTS}
${UNKNOWN_CERTS}"
    NAGIOS_STATE=1
elif [ ${N_UNKNOWN} -gt 0 ]; then
    INFO="UNKNOWN ${N_UNKNOWN}/${N_TOTAL} certificates, ${N_OK} OK"
    INFO="${INFO}
${UNKNOWN_CERTS}"
    NAGIOS_STATE=3
else
    INFO="OK - All certificates are valid"
    NAGIOS_STATE=0
fi

INFO=`echo "${INFO}" | sed 's/[[:space:]]$//g'`
echo "${INFO}" > ${NAGIOS_FILE}
echo "mtime: `date +%s`" >> ${NAGIOS_FILE}
echo "exit: ${NAGIOS_STATE}" >> ${NAGIOS_FILE}
exit
