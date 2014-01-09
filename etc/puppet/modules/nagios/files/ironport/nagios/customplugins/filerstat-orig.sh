#!/bin/sh

#
# Global Variables
#

PATH=/bin:/usr/bin:/usr/local/bin

PN=`basename "$0"`
BASE_OID_DF=".1.3.6.1.4.1.789.1.5.4.1"
TOTALKBYTES=".1.3.6.1.4.1.789.1.5.4.1.15"
USEDKBYTES=".1.3.6.1.4.1.789.1.5.4.1.17"
MAXFILESUSED=".1.3.6.1.4.1.789.1.5.4.1.12"
MIB="/usr/local/mibs/netapp.mib"
DEBUG=0

Spit () {
if [ $DEBUG -eq 1 ]
then
printf "\n__BEGIN_DEBUG__\n$@\n__END_DEBUG__\n"
fi
}

Usage () {
printf "Usage: %s: [-d] [ -h ] [-m] -f filer -v volume \n" $0
exit;
}

#
# MAIN
#

while getopts v:f:dhm option
do
case "$option" in
f) FILER="$OPTARG";;
v) VOLUME="$OPTARG";;
d) DEBUG=1;;
h) HUMAN=1;; #TODO
m) MRTG=1;; #TODO
?) Usage;;
esac
done
shift `echo "$OPTIND - 1" | bc`

if [ -z "$FILER" -o -z "$VOLUME" ]
then
Usage;
fi

Spit "snmpwalk -On -m $MIB -c public -v1 $FILER ${BASE_OID_DF}.2 | grep -w $VOLUME | grep -v snapshot | grep -v '\.\.' | awk '{print \$1}' | awk -F'.' '{print \$NF}'"

VOLID=`snmpwalk -On -m $MIB -c public -v1 $FILER ${BASE_OID_DF}.2 | grep -w $VOLUME | grep -v snapshot | grep -v '\.\.' | awk '{print \$1}' | awk -F'.' '{print \$NF}'`

if [ "X$VOLID" = "X" ]
then
Spit "No OID found for ${FILER}:/vol/${VOLUME}";
printf "ERROR: No volume info\n";
exit 2;
fi

total=`snmpget -On -m $MIB -c public -v1 $FILER ${TOTALKBYTES}.$VOLID | awk '{print $NF}'`
inuse=`snmpget -On -m $MIB -c public -v1 $FILER ${USEDKBYTES}.$VOLID | awk '{print $NF}'`
nfiles=`snmpget -On -m $MIB -c public -v1 $FILER ${MAXFILESUSED}.$VOLID | awk '{print $NF}'`

totalgb=`echo "scale=2; $total / ( 1024 * 1024)" | bc` inusegb=`echo "scale=2; $inuse / ( 1024 * 1024)" | bc`
nfilesm=`echo "scale=2; $nfiles / 1000000" | bc` avgfilesize=`echo "scale=2; $inuse / $nfiles" | bc`

echo ""
echo "capacity (GB):\t\t$totalgb"
echo "usage (GB):\t\t$inusegb"
echo "files (m):\t\t$nfilesm"
echo "avg file size (KB):\t$avgfilesize"
echo ""
