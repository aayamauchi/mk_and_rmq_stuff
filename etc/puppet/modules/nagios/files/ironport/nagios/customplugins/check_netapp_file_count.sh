#!/bin/sh -
#
# check number of files on netapp volume
#

# change as needed...
MIB="/usr/local/ironport/netapp/MIB/netapp.mib"
ROCOMMUNITY=y3ll0w\!
SNMPGET=/usr/bin/snmpget
SNMPWALK=/usr/bin/snmpwalk

# shouldn't need to change...
PN=`basename "$0"`
BASE_OID_DF=".1.3.6.1.4.1.789.1.5.4.1"
TOTALKBYTES=".1.3.6.1.4.1.789.1.5.4.1.15"
USEDKBYTES=".1.3.6.1.4.1.789.1.5.4.1.17"
MAXFILESUSED=".1.3.6.1.4.1.789.1.5.4.1.12"
DEBUG=0

usage () {
	printf "Usage: %s: -c <crit> -w <warn> -f <filer> -v <volume> \n" $0
	exit;
}

while getopts c:w:v:f: option
do
case "$option" in
c) CRIT="$OPTARG";;
w) WARN="$OPTARG";;
f) FILER="$OPTARG";;
v) VOLUME="$OPTARG";;
?) Usage;;
esac
done
shift `echo "$OPTIND - 1" | bc`

[ -z "$FILER" -o -z "$VOLUME" -o -z "$CRIT" -o -z "$WARN" ] && usage;

VOLID=`$SNMPWALK -On -m $MIB -c $ROCOMMUNITY -v1 $FILER ${BASE_OID_DF}.2 \
	| grep -w $VOLUME \
	| grep -v snapshot \
	| grep -v '\.\.' \
	| awk '{print \$1}' \
	| awk -F'.' '{print \$NF}'`

if [ "X$VOLID" = "X" ]
then
	printf "ERROR: No volume info\n";
	exit 2;
fi

nfiles=`$SNMPGET -On -m $MIB -c $ROCOMMUNITY -v1 $FILER ${MAXFILESUSED}.$VOLID | awk '{print $NF}'`

EXIT_STATUS=0; EXIT_MSG="OK: $nfiles files"
if [ $nfiles -gt $CRIT ]
then
	EXIT_MSG="ERROR: $nfiles files above threshold ($CRIT)"
	EXIT_STATUS=2
elif [ $nfiles -gt $WARN ]
then
	EXIT_MSG="WARNING: $nfiles files above threshold ($WARN)"
	EXIT_STATUS=1
fi

echo $EXIT_MSG
exit $EXIT_STATUS

