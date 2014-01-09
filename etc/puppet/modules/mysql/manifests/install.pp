# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $
#
# Attempt to install the following packages
#     MySQL-client-advanced,
#     MySQL-server-advanced,
#     MySQL-shared-compat-advanced, 
######################################################################


# Para-meterized classes are used to pass the package names
# @param:server- MySQL server package to be installed
# @param:client- MySQL client package to be installed
# @param:shared- MySQL shared package to be installed
# @param:path  - Provides the path for MySQL packages

class mysql::install ($server,$client,$shared,$path) {

# Metaparameter for Package 
# Requires class mysql::pre_install
# Using "rpm" for installing packages

  Package {   provider => rpm,
              ensure   => installed,
              require  =>[Class["mysql::pre_install"],]
          }


/*  exec    { "MySQL_server_advanced":
            command => "/bin/rpm -if http://install.eng.sbr.ironport.com/pub/linux/rh5/RPMS/x86_64/$server",
            require =>Class["mysql::pre_install"],
            creates => "/var/lib/mysql", 
            logoutput => true,
          }*/

# Installs MySQL-server-advanced

  package { "MySQL_server_advanced":
              source   => "$path$server", 
          }


# Installs MySQL-client-advanced

 package {  "MySQL_client_advanced":
            source   => "$path$client",
         }


# Installs MySQL-shared-advanced
# Requires Package MySQL-server-advanced 

 package {   "MySQL_shared_advanced":
             source   => "$path$shared",
             require  => Package ['MySQL_server_advanced'],
         }

} #end of class
