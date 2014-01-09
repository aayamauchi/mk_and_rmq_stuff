 x="$(/bin/ps -ef | grep -ic 'mysql')"
if [ $x -eq '5' ]
   then
     echo "MySQL is  Successfuly Installed "
else
    echo "MySQL Installation failed. Please verify the Install "
fi
