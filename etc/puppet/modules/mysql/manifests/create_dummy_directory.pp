# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $
# Create a temporary directory to prevent puppet from executing the MySQL module more then once
#######################################################################################



class mysql::create_dummy_directory{

 # A temporary directory 'mysql_puppet' is created when MySQL module is executed the very time
 # This is a temporary fix until the cron script takes care of this functionality

    exec   {   "create_dummy_directory":
               command   => "/bin/mkdir /data/mysql_puppet",
               logoutput => true,
           }


} # END OF CLASS
