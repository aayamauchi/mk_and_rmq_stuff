#!/bin/sh

# Script to check for a mounted filesystem on a remote host
args=`getopt H:f: $*`

if [ $? -ne 0 ]
then
    echo "syntax: $0 -H <host> -f <filesystem>"
fi

set -- $args

for i
do
    case "$i" in
        -H)
            host="$2"
            shift
            shift
            ;;
        -f)
            filesystem="$2"
            shift
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ ${host:-x} = 'x' ]
then
    echo "syntax: $0 -H <host> -f <filesystem>"
    exit 2
fi

/usr/bin/ssh ${host} "df -k | grep $filesystem" > /dev/null 2>&1

RETURN=$?

if [ $RETURN -ne 0 ]
then
    echo "CRITICAL - Filesystem ${filesystem} is not mounted on ${host}.  Got return ${RETURN}."
    exit 2
fi

echo "OK - Filesystem ${filesystem} is mounted on ${host}."
exit 0
