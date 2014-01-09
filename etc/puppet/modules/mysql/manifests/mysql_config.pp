
# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $
# Apply the DBA and Sysops database grants for standard user-hosts
# Set up the sysops table on the master database
######################################################################


class mysql::mysql_config {

# Copy the Grant Script from puppet directory into /data directory

 file {  "/data/apply_standard_grants_mysql5+.sql":
         alias   => "grant_revoke_script",
         owner   => "mysql",
         ensure  => present,
         source  => "/etc/puppet/test/modules/mysql/files/apply_standard_grants_mysql5+.sql",
      }


# Execute the Grant Script, to set default DBA and sysops passwords
# Requires "apply_standard_grants_mysql5+.sql" file to be available
# Requires MySQL to be running

  exec {    "run_password_config":
            command   => "/usr/bin/mysql < /data/apply_standard_grants_mysql5+.sql",
            require   => Class["mysql::service"],           
            # require =>[ File["grant_revoke_script"],Exec["mysql_start", "create_sysops_db"],],
            logoutput => true,
       }


#Create sysops Database for replication, if it is a Master server

$awesome_purpose = downcase($::awesome_purpose)

if($awesome_purpose=='dbm')
{
 # Copy the create_sysops_db Script from puppet directory into /data directory
 file {  "/data/create_sysops_db_script.sql":
         alias   => "create_sysops_db_script",
         owner   => "mysql",
         ensure  => present,       
         source  => "/etc/puppet/test/modules/mysql/files/create_sysops_db_script.sql",
      }


# Execute the create_sysops_db Script, to create default sysops tables
# Requires "apply_standard_grants_mysql5+.sql" file to be available
# Requires MySQL to be running

  exec {   "create_sysops_db":
            command   => "/usr/bin/mysql < /data/create_sysops_db_script.sql",
            require   => Class["mysql::service"],           
            # require =>[ File["create_sysops_db_script"],Exec["mysql_start"],],
            logoutput => true,
       }
}
/*
exec {   "mysql_start":
         command => "/etc/rc.d/init.d/mysql start",
         require => [Class["mysql::my_cnf_config"],File["performance_schema"],],
         logoutput => true,
     }
*/

} #end of class
