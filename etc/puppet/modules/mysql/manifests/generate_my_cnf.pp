
# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $

# Generates a my.cnf (MySQL Configuration file based on the system memory
# Confugres the my.cnf according to the awesome_purpose
# Requires config class

######################################################################

class mysql::generate_my_cnf ($email) {

 $awesome_purpose = downcase($::awesome_purpose)

#  Get third and fourth octet of ip address to set serverID and hostname in my.cnf file

  $ip3 = regsubst($ipaddress,'^(\d+)\.(\d+)\.(\d+)\.(\d+)$','\3')
  $ip4 = regsubst($ipaddress,'^(\d+)\.(\d+)\.(\d+)\.(\d+)$','\4')


# Obtain the Total Memory of the system to decide on the configuration file (my.cnf)
  
   $mem=$::memorytotal
   $m= chop($::memorytotal)
   $m1= chop($m)
   $integer_mem= chop($m1)

# Metaparameter for file
 
  File   {
           require => Class["mysql::config"],
           path    => "/data/mysql/my.cnf",
           mode    => "0660",
           ensure  => "present",
         }

# Configure MySQL with standard my.cnf based on Total Memory of the System  

 if(($integer_mem < 34) and ($integer_mem > 31)) 
  {
    # 32G system
    file {  "my.cnf" :
            source  => "/etc/puppet/test/modules/mysql/files/my.cnf.master.32G",
         }
  }
 elsif(($integer_mem < 97) and ($integer_mem > 94))
  {
    # 96G System
    file { "my.cnf" :
           source  => "/etc/puppet/test/modules/mysql/files/my.cnf.master.96G",
         }
  }
 elsif(($integer_mem < 18) and ($integer_mem > 14))
  {
    # 16G System
    file { "my.cnf" :
           source  => "/etc/puppet/test/modules/mysql/files/my.cnf.master.16G",
         }
  }
 elsif(($integer_mem < 10) and ($integer_mem > 6))
  {
    # 8G System
    file { "my.cnf" :
           source  => "/etc/puppet/test/modules/mysql/files/my.cnf.master.8G",
         }
  }
  else
  {
     exec   {   "non_standard_DB_machine":
               command   => "/bin/echo Not a Standard Database Machine, MySQL installation failed on  $::fqdn. | mail -s 'Puppet MySQL Install on $::fqdn' $email",
               logoutput => true,
           } 
     
     exec   {  "remove_data_directory":
               command   => "/bin/rm -rf /data/mysql",
               logoutput => true,
               require   => File["my.cnf"],
            }

     file { "my.cnf" :
          }
     
  }
#End of ifelse construct


/*
else
 {
   #  Create Default my.cnf for all other Servers
   #  Create my.cnf from the template in /etc/puppet/modules/mysql/templates/mycnf.erb
   #  Calculate and update the buffer_pool_size
   
  /* file {  "my.cnf":
           content => template("/etc/puppet/test/modules/mysql/templates/mycnf.erb"),
        }

  $buffer_pool_size=$integer_mem*5/8

   exec {  "my_cnf_buffer_pool_size":
           command => "/bin/sed -i 's/<buffer-pool-size>/$buffer_pool_size/g' /data/mysql/my.cnf",
           logoutput => true,
           require => File["my.cnf"],
        }

 }*/
 #End of ifelse construct


# Update the serverID and the hostname

 exec {    "my_cnf_ipaddress":
           command   => "/bin/sed -i 's/<ip3><ip4>/$ip3$ip4/g' /data/mysql/my.cnf",
           logoutput => true,
           require   => File["my.cnf"],
      }

 exec {    "my_cnf_log_bin":
           command   => "/bin/sed -i 's/<host_name>/$hostname/g' /data/mysql/my.cnf",
           logoutput => true,
           require   => File["my.cnf"],
      }

 if (($awesome_purpose=='dbss') or( $awesome_purpose=='dbs')) 
  {
    exec {  "add_readonly":
            command => "/bin/echo readonly >> /data/mysql/my.cnf",
            require => File["my.cnf"],
         }
  } 
 elsif (($awesome_purpose=='dbms') )
  {
    exec {  "add_log-slave-updates":
            command => "/bin/echo log-slave-updates >> /data/mysql/my.cnf",
            require => File["my.cnf"],
         }
  }
# End of ifelse construct

}# end of class
