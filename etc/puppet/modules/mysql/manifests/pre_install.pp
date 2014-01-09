# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $
# Prepares the environment for successfull installation of MySQL
#   Purge /var/lib/mysql 
#   Configure yum.conf file
######################################################################


class mysql::pre_install{

# Check again for pre-installed MySQL packages before purging /var/lib/mysql
# FYI:-/var/lib/mysql interferes with package installation, so getting rid of it 
 
 exec { "var_lib_mysql_ensure_absent":
         command => "/bin/rm -rf /var/lib/mysql ",
         unless  => "/bin/rpm -qa | grep -ic mysql",
         logoutput => true,
       }

# Configuring yum.conf file => set gpcheck=1;

 exec {    "yum.conf":
           command => "/bin/sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.conf",
           onlyif => "/bin/grep 'gpgcheck=1' /etc/yum.conf ",
           logoutput => true,
      }

}#End of class

 


