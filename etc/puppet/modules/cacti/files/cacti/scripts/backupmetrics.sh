#!/usr/local/bin/bash
# $0 host numindexes
# $0 host index
# $0 host query field
# $0 host get field $index

PATH=/bin:/usr/bin:/usr/local/bin

if [ "$1" == "" ] || [ "$2" == "" ]
then
    echo "USAGE: $0 dbhostname [index|query <field>|get <field> <index>]"
elif [ "$2" == "numindexes" ]
then
    sql="select count(distinct(servername)) from backups"
    out=`echo ${sql} | mysql -N -ucactiuser -pcact1pa55 -h $1 backup_metrics`
    echo $out
elif [ "$2" == "index" ] 
then
    sql="select distinct(servername) from backups order by servername"
    out=`echo ${sql} | mysql -N -ucactiuser -pcact1pa55 -h $1 backup_metrics`
    echo "${out}"
elif [ "$2" == "query" ] 
then
    if [ "$3" == "" ]
    then
        echo "Must supply parameter to query"
    else
        # backup data
        backup_sql="select UNIX_TIMESTAMP(endtime), size, ((UNIX_TIMESTAMP(endtime) - UNIX_TIMESTAMP(starttime))/60) as duration from backups where servername='${3}' and success=1 order by starttime desc limit 1"
        backup_out=`echo ${backup_sql} | mysql -N -ucactiuser -pcact1pa55 -h $1 backup_metrics`
        echo "backup_unixtime:`echo "${backup_out}" | awk '{print $1}'`"
        echo "backup_mbytes:`echo "${backup_out}" | awk '{print $2}'`"
        echo "backup_minutes:`echo "${backup_out}" | awk '{print $3}'`"

        # restore data
        restore_sql="select UNIX_TIMESTAMP(endtime), size, ((UNIX_TIMESTAMP(endtime) - UNIX_TIMESTAMP(starttime))/60) as duration from restores where servername='${3}' and success=1 order by starttime desc limit 1"
        restore_out=`echo ${restore_sql} | mysql -N -ucactiuser -pcact1pa55 -h $1 backup_metrics`
        echo "restore_unixtime:`echo "${restore_out}" | awk '{print $1}'`"
        echo "restore_mbytes:`echo "${restore_out}" | awk '{print $2}'`"
        echo "restore_minutes:`echo "${restore_out}" | awk '{print $3}'`"
    fi
elif [ "$2" == "get" ]
then
    if [ "$3" == "" ] || [ "$4" == "" ]
    then
        echo "Must supply parameter and index to get"
    else
        # backup data
        backup_sql="select UNIX_TIMESTAMP(endtime), size, ((UNIX_TIMESTAMP(endtime) - UNIX_TIMESTAMP(starttime))/60) as duration from backups where servername='${3}' and success=1 order by starttime desc limit 1"
        backup_out=`echo ${backup_sql} | mysql -N -ucactiuser -pcact1pa55 -h $1 backup_metrics`

        # restore data
        restore_sql="select UNIX_TIMESTAMP(endtime), size, ((UNIX_TIMESTAMP(endtime) - UNIX_TIMESTAMP(starttime))/60) as duration from restores where servername='${3}' and success=1 order by starttime desc limit 1"
        restore_out=`echo ${restore_sql} | mysql -N -ucactiuser -pcact1pa55 -h $1 backup_metrics`

	case "${4}" in
            "backup_unixtime" ) echo "`echo "${backup_out}" | awk '{print $1}'`" ;;
            "backup_mbytes" ) echo "`echo "${backup_out}" | awk '{print $2}'`" ;;
            "backup_minutes" ) echo "`echo "${backup_out}" | awk '{print $3}'`" ;;
            "restore_unixtime" ) echo "`echo "${restore_out}" | awk '{print $1}'`" ;;
            "restore_mbytes" ) echo "`echo "${restore_out}" | awk '{print $2}'`" ;;
            "restore_minutes" ) echo "`echo "${restore_out}" | awk '{print $3}'`" ;;
        esac
    fi
fi
