# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $
# Post configuration class- to Install and Configure MySQL, performs the following functions :-
#    Runs the command mysql_install_db
#    Changes ownership of performace_schema to MySQL
#    Edit the MySQL startup script, to include the  arguments --defaults-file=$datadir/my.cnf 
######################################################################

class mysql::post_config {

# Runs the command mysql_install_db and changes the ownership of /data/mysql and /data to MySQL
# Requires Insall and config class

 exec {  "mysql_install_db":
         command => "/usr/bin/mysql_install_db && chown -R mysql:mysql /data ",
         require => Class["mysql::install", "mysql::config"],
         logoutput => false, 
      }


# Edit the MySQLstartup script, at approximately line 283
# Include the  arguments --defaults-file=$datadir/my.cnf 

 exec {  "mysql_startup_scrpt":
         command =>"/bin/sed -i 's/mysqld_safe --datadir/mysqld_safe  --defaults-file=\$datadir\/my.cnf --datadir/g' /etc/rc.d/init.d/mysql",         
         require => Exec["mysql_install_db"],
         logoutput => true,
      }

#  Change ownership of performance_schema to mysql:mysql
#  Requires execution of mysql_install_db

 file {  "performance_schema":
         path    => '/data/mysql/performance_schema',
         #owner  => "mysql",
         require => Exec["mysql_install_db"]
      }

} # end of class

