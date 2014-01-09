/bin/rpm -qa | grep -ic mysql
if [ $? -eq 0 ]
then echo '1'
else
echo '0'
fi
