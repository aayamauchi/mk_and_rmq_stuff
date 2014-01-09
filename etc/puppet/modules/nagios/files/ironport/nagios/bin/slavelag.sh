#!/bin/sh

PATH=/bin:/usr/bin:/sbin:/usr/sbin

# step through and get values for command line arguments
# echo usage if incorrect argument found
while [ $# -gt 0 ]; do
    case "$1" in
    -a)  application="$2"; shift;;
    --)	shift; break;;
    -*)
        echo >&2 \
        "usage: $0 -a {corpus|sbrs|senderbase|spamcop}"
        exit 1;;
    *)  break;;	# terminate while loop
    esac
    shift
done

# Exit if user did not define an application to query on
if [ x${application} = x ]; then
    echo "You must specify an application to query on!"
    echo "usage: $0 -a {corpus|sbrs|senderbase|spamcop|toc}"
    exit 1
fi

corpus="corpus2-db3.soma corpus2-db4.soma corpus2-db5.soma corpus2-db6.soma corpus2-db7.soma corpus2-db8.soma"
spamcop="sc-db2.soma sc-db3.soma sc-db4.soma"
senderbase="sb-db2.soma sb-db3.soma sb-db4.soma sb-db5.soma sb-db1.mega sb-db2.mega sb-db3.mega sb-db-s2-1.coma sb-db-s2-2.coma sb-db-s2-3.coma sb-db-s2-4.coma"
sbrs="sbrs-db2.soma sbrs-db4.mega sbrs-db5.mega sbrs-db6.mega sbrs-db-s2-1.coma sbrs-db-s2-2.coma sbrs-db-s2-3.coma sbrs-db-s2-4.coma"
toc="toc4-adb2.soma toc4-adb4.soma"

case $application in
corpus)
  serverlist=`echo $corpus`
  ;;
spamcop)
  serverlist=`echo $spamcop`
  ;;
sbrs)
  serverlist=`echo $sbrs`
  ;;
senderbase)
  serverlist=`echo $senderbase`
  ;;
toc)
  serverlist=`echo $toc`
  ;;
*)
    echo "Unrecognized application; options are corpus sbrs senderbase spamcop toc"
    echo "usage: $0 -a application"
    exit 1
esac

echo "Slave Lag: "

for server in $serverlist; do
  echo -n "${server}	"
  /usr/local/ironport/nagios/customplugins/check_db_replication.py -H ${server}.ironport.com -u nagios -p thaxu1T -d sysops -w 1800 -c 10000 -v 4.1
done

echo ""

exit 0
