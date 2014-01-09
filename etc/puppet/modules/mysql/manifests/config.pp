# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $
# Prepares the directory structure for MySQL server Startup
#   Ensures mysql data directory, temp directory, mysql_log directory are present with correct ownership
#   Ensure symlink is set for the mysql directory,
#   Has a dependency on mysql::Install class 
######################################################################

class mysql::config {

#  Global definition for File resource
#  Setting owner: group => mysql:mysql

FILE {
	owner   => "mysql",
        group   => "mysql",
     }


#  Ensure /data, /data/tmp,/data/mysql_log directory are present, with correct ownership

$mysql_dirs = [ "/data", "/data/tmp", "/data/mysql_log",]

file {   $mysql_dirs:
    	 ensure => "directory",
         mode   => 0700,
     }

#  Ensure /data/mysql is present with correct ownership

file{"/data/mysql":
         ensure => "directory",
    	 mode   => 0755,
         recurse =>true,
  }

#  Ensure symlink for /var/lib/mysql is set for the mysql directory

file {	 '/var/lib/mysql':
   	 ensure => 'link',
   	 target => '/data/mysql',
         force  => true,
     }
 
} #end of class

