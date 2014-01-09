#!/usr/local/bin/bash -

PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin"
exit_message="OK"
exit_status="0"

######################################################################
# subs
######################################################################

usfile()
{
	echo "USAGE: `basename $0` -h hostname -f filename -w warningsecs -c criticalsecs"
	exit 0
}

print_status()
{
	[ "$1" ] && exit_message="$1"
	[ "$2" ] && exit_status="$2"
	echo "$exit_message"
	exit $exit_status
}

check_file()
{
    [ "$1" ] && file="$1"
    date=`date +%s`
    file=`echo ${date} - ${file} | bc`

    if [ "${file}" -ge "${critical}" ]
    then
        exit_message="CRITICAL - $filename $file > $critical seconds"
        exit_status="2"
        print_status
    elif [ "${file}" -ge "${warning}" ]
    then
        exit_message="WARNING - $filename $file > $warning seconds"
        exit_status="1"
        print_status
    fi
}
######################################################################
# main
######################################################################

# must have "-d <domain>"
[ $# -ge 4 ] || usfile

# process command line args
while getopts h:f:w:c:a arg
do
    case "$arg" in
     h) hostname="$OPTARG";;
     f) filename="$OPTARG";;
     w) warning="$OPTARG";;
     c) critical="$OPTARG";;
     *) usfile;;
    esac
done

# is filename a directory?
lastchar=`echo ${filename}|sed -e 's/\(^.*\)\(.$\)/\2/'`

if [ "${lastchar}" == "/" ]
then
    isdir="yes"
fi

if [[ "${filename}" == *** ]]
then
    glob="yes"
    if [ "${isdir}" == "yes" ]
    then
        exit_message="globbing not supported with directories"
        exit_status="3"
    fi
fi

dateY=`date +%Y`
datem=`date +%m`
dated=`date +%d`

filename=`echo ${filename} | sed -e "s/%Y/${dateY}/"`
filename=`echo ${filename} | sed -e "s/%m/${datem}/"`
filename=`echo ${filename} | sed -e "s/%d/${dated}/"`

os_version=`ssh nagios@${hostname} "uname"`

if [ "${isdir}" == "yes" ]
then
    if [ "$os_version" == "FreeBSD" ]
    then
        file=`ssh nagios@${hostname} "find ${filename} -type f -exec stat -f %m {} \; 2>/dev/null |sort -n |head -1"`
    else
        file=`ssh nagios@${hostname} "find ${filename} -type f -exec stat -c %Y {} \; 2>/dev/null |sort -n |head -1"`
    fi
elif [ "${glob}" == "yes" ]
then
    if [ "$os_version" == "FreeBSD" ]
    then
        file=`ssh nagios@${hostname} "find ${filename} -type f -exec stat -f %m {} \; 2>/dev/null |sort -nr |head -1"`
    #Determine filename based on same mtime criteria
	filename=`ssh nagios@${hostname} "find ${filename} -type f -exec stat -f '%m %N' {} \; 2>/dev/null | sort -nr | head -1|cut -d' ' -f2"`
    else
        file=`ssh nagios@${hostname} "find ${filename} -type f -exec stat -c %Y {} \; 2>/dev/null |sort -nr |head -1"`
        filename=`ssh nagios@${hostname} "find ${filename} -type f -exec stat -c '%m %n' {} \; 2>/dev/null | sort -nr | head -1|cut -d' ' -f2"`
    fi
else
    if [ "$os_version" == "FreeBSD" ]
    then
        file=`ssh nagios@${hostname} "stat -f %m ${filename} 2>/dev/null"`
    else
         file=`ssh nagios@${hostname} "stat -c %Y  ${filename} 2>/dev/null"`
    fi
fi

if [ "${isdir}" != "yes" ]
then
    test=`echo "0${file} * 1" | bc`
    if [ "${test}" != "${file}" ]
    then
	exit_message="UNKNOWN - $filename does not exist?"
	exit_status="3"
	print_status
    fi
fi

date=`date +%s`

if [ "${isdir}" == "yes" ]
then
    for x in ${file}
    do
	check_file $x
    done

    exit_message="OK - All files current"
    exit_status="0"
    print_status
else
    check_file $file

    exit_message="OK - $filename $file seconds old"
    exit_status="0"
    print_status
fi
