#!/usr/local/bin/bash
# SBRS Data 1.0 Monitoring Dynamic Paths Checks
# Eng Owner: Pawan Dube
# MonOps: Valerii Kafedzhy (vkafedzh@cisco.com)
# See MONOPS-1360
#==============================================================================

PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin"
exit_message="OK"
exit_status="0"

######################################################################
# subs
######################################################################

usfile()
{
	echo "USAGE: `basename $0` -h hostname -f [ipv4|ipv6|rule] -u user -p passwd -c criticalsecs"
	exit 3
}

######################################################################
# main
######################################################################

[ $# -ge 6 ] || usfile

# process command line args
while getopts h:f:c:u:p:a arg
do
    case "$arg" in
     h) hostname="$OPTARG";;
     f) file="$OPTARG";;
     u) user="$OPTARG";;
     p) password="$OPTARG";;
     c) critical="$OPTARG";;
     *) usfile;;
    esac
done

lastchar=`echo ${file}|sed -e 's/\(^.*\)\(.$\)/\2/'`

if [ "${lastchar}" == "/" ]
then
	usfile
fi

if [ "${file}" == "ipv4" ]; then
	filename=`ssh nagios@${hostname} "python2.6 -c \"import json; import glob; d=[open(f).readlines()[-1] for f in glob.glob('/data/var/meta_data/sbrs_sbrs_rep*.upd')]; p=[json.loads(i) for i in d]; print '\n'.join(['/'.join(['/data/var/sbrs_data/updates',i['uri'], i['base']['file']]) for i in p]); \"" | grep "ipv4"`
elif [ "${file}" == "ipv6" ]; then
	filename=`ssh nagios@${hostname} "python2.6 -c \"import json; import glob; d=[open(f).readlines()[-1] for f in glob.glob('/data/var/meta_data/sbrs_sbrs_rep*.upd')]; p=[json.loads(i) for i in d]; print '\n'.join(['/'.join(['/data/var/sbrs_data/updates',i['uri'], i['base']['file']]) for i in p]); \"" | grep "ipv6"`
elif [ "${file}" == "rule" ]; then
	filename=`ssh nagios@${hostname} "python2.6 -c \"import json; import glob; d=[open(f).readlines()[-1] for f in glob.glob('/data/var/meta_data/sbrs_sbrs_rule**.upd')]; p=[json.loads(i) for i in d]; print '\n'.join(['/'.join(['/data/var/sbrs_data/updates',i['uri'], i['rule_db']['file']]) for i in p]); \""`
fi
/usr/local/ironport/nagios/customplugins/check_remote_file.py -H ${hostname} -u ${user} -p ${password} -f ${filename} -a ${critical}
