#!/usr/bin/env bash

EXIT_OK=0
EXIT_WARN=1
EXIT_CRIT=2
EXIT_UNK=3

usage() {
    cat << EOF
    USAGE: $(basename $0) -h <hostname> -t Target <production|friendlies|hotpatch> -f <file name> -w <warning threshold> -c <critical threshold> -v verbosity
    Required Options:
    -h Hostname
    -t Target Directory
    -f Filename
    -w Warning threshold
    -c Critical threshold
EOF
}


if [[ $# -lt 4 ]]
then
   usage
   exit $EXIT_UNK 
fi

#FilePath="/usr/local/ironport/case_packager_data/targets/production/"
#FilePath="/usr/local/ironport/case_packager_data/case_packager_data/targets/prod_mirror"
Target=""
Host=""
File=""
warning=""
critical=""
verbose=""

while getopts h:t:f:w:c:v ARGS
do
    case $ARGS in
        h) Host="$OPTARG"
        ;;
        t) Target="$OPTARG"
        ;;
        f) File="$OPTARG"
           FilePath="$Target/$OPTARG"
        ;;
        w) warning="$OPTARG"
        ;;
        c) critical="$OPTARG"
        ;;
        v) verbose=1
        ;;
        *) echo "UNKNOWN variable"
           exit $EXIT_UNK
        ;;
    esac
done

for reqopt in Host Target File warning critical
do
    if [ -z ${!reqopt} ]
    then
        echo -e "$reqopt MUST be specified\n"
        usage
        exit $EXIT_UNK
    fi
done

LatestFile=`ssh ${Host} ls -lt ${FilePath} 2>/dev/null | head -n 1 | awk -F " " '{ print $9 }'`
[[ -z $LatestFile ]] && {
        echo "UNKNOWN. File :: $FilePath not found at $Host"
        exit $EXIT_UNK 
}

[[ $verbose -gt 0 ]] && {
        echo $LatestFile
}

LatestFileTimestamp=`ssh ${Host} stat -f %c ${LatestFile}`
[[ $verbose -gt 0 ]] && {
        echo -n "CTIME Timestamp ${LatestFileTimestamp} "
        echo $(date -d @${LatestFileTimestamp})
}

CurTime=$(date +%s)
DiffTime=$(echo ${CurTime} - ${LatestFileTimestamp}| bc)

if [[ $DiffTime -lt $warning ]]
then
    echo "OK. File ${LatestFile} was created ${DiffTime} seconds ago"
    exit $EXIT_OK 
fi

if [[ $DiffTime -ge $warning ]] && [[ $DiffTime -lt $critical ]]
then
    echo "Warning. File ${LatestFile} was created ${DiffTime} seconds ago"
    exit $EXIT_WARN
fi

if [[ $DiffTime -ge $critical ]]
then
   echo "Critical. File ${LatestFile} was created ${DiffTime} seconds ago"
   exit $EXIT_CRIT
fi

