#!/usr/local/bin/bash

# $0 <host> <user> <pass>


PATH=/bin:/usr/bin:/usr/local/bin

USER=`mysql -h $1 -u $2 -p$3 -e "SELECT user, host, password FROM mysql.user WHERE user IN('root','test') OR PASSWORD ='' OR user=''"`
#DB=`mysql -h $1 -u $2 -p$3 -e "SHOW DATABASES LIKE 'test'"`

if [ "$USER" != "" ]
then
    printf "%b" "User Validation Failed\n$USER\n"
fi
#if [ "$DB" != "" ]
#then
#    printf "%b" "DB Validation Failed\n$DB\n"
#fi

#if [ "$USER" == "$DB" ]
if [ "$USER" == "" ]
then
    echo "User validation passed"
    exit 0
else
    exit 2
fi
