#!/bin/sh -
# check specified domain against akamai's servers for soa mismatch.

PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin"
# used for "internal" check; this host needs an acl
# entry for the server/IP running this check
ns1_soma="204.15.82.70"
# healthy defaults
exit_message="OK"
exit_status="0"

######################################################################
# subs
######################################################################

usage()
{
	echo "USAGE: `basename $0` -d <domain> [-i]"
	exit 0
}

print_status()
{
	[ "$1" ] && exit_message="$1"
	[ "$2" ] && exit_status="$2"
	echo "$exit_message"
	exit $exit_status
}

######################################################################
# main
######################################################################

# must have "-d <domain>"
[ $# -ge 2 ] || usage

# process command line args
while getopts d:i arg
do
    case "$arg" in
     d) domain="$OPTARG";;
     i) internal="true";;
     *) usage;;
    esac
done

if [ -z "$internal" ]
then
    soa=`host -tsoa $domain | awk '{print $7}'`
else
    soa=`host -tsoa $domain $ns1_soma | awk '{print $7}'`
fi

if [ "x${soa}" = x ]
then
	exit_message="CRITICAL - no soa found for domain: $domain"
	exit_status="2"
else
	for server in `host -tns $domain | awk '{print $NF}'`
	do
		soaprime=`host -tsoa $domain $server | tail -1 | awk '{print $7}'`
		if [ $soa -ne $soaprime ]
		then
			bad_servers="$server $bad_servers"
			exit_message="CRITICAL - mismatched soa: $bad_servers"
			exit_status="2"
		fi
	done
fi

print_status

