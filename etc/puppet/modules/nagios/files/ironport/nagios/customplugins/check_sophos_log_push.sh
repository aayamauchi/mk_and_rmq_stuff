#!/bin/sh

file="/tmp/scp_dummy_file"
touch ${file}
args=`getopt H:p: $*`

if [ $? -ne 0 ]
then
    echo "syntax: $0 -H <host> [-p <port>]"
fi

port=22

set -- $args

for i
do
    case "$i" in
        -H)
            host="$2"
            shift
            shift
            ;;
        -p)
            port="$2"
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
    echo "syntax: $0 -H <host>"
    exit 2
fi

/usr/bin/scp -P ${port} ${file} mga@${host}: > /dev/null 2>&1

RETURN=$?

if [ $RETURN -ne 0 ]
then
    echo "CRITICAL - Unable to scp ${file} to ${host}.  Got return ${RETURN}."
    exit 2
fi

echo "OK - scp of ${file} to ${host} succeeded."

