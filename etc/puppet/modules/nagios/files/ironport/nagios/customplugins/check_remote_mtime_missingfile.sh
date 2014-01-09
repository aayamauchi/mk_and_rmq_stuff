#!/usr/local/bin/bash -
#==============================================================================
# check_remote_mtime_missingfile.sh
#
# Wrapper for check_remote_mtime.sh to treat missing file (UNKNOWN) as OK.
# Note that this will mask extended UKNOWN status.
#==============================================================================
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin"
EXIT_MESSAGE="OK - File does not exist"
EXIT_STATUS=0

RESULT_MESSAGE=`/usr/local/ironport/nagios/customplugins/check_remote_mtime.sh ${*}`
RESULT_STATUS=${?}

# Pass along any result unless it's 3 (UNKNOWN/missing file).
if [ ${RESULT_STATUS} -ne 3 ]; then
   EXIT_MESSAGE=${RESULT_MESSAGE}
   EXIT_STATUS=${RESULT_STATUS}
fi

echo "${EXIT_MESSAGE}"
exit ${EXIT_STATUS}
