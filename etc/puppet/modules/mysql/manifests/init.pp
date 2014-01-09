# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $
# MySQL installation starts if the aweseom_purpose is either dbm/dbs/sbms/sbss
# MySQL installation termiantes if pre-installed MySQL packages or /data/mysql is found

# This is the File the puppet looks into when MySQL installation is  started
#######################################################################################

class mysql {

# MySQL Package variables- to be edited here incase of future changes in MySQL Versions
# Path for MySQL packages 
# Email address of DBA

 $server  = "MySQL-server-advanced-5.5.8-1.rhel5.x86_64.rpm"
 $client  = "MySQL-client-advanced-5.5.8-1.rhel5.x86_64.rpm"
 $shared  = "MySQL-shared-compat-advanced-5.5.8-1.rhel5.x86_64.rpm"
 $path    = "http://install.eng.sbr.ironport.com/pub/linux/rh5/RPMS/x86_64/"
 $email   = "ajvijaya@cisco.com"
 

# Puppet Run Stages
  stage {"pre"     : before  => Stage["main"]}
  stage {"post"    : require => Stage["main"]}
  stage {"email"   : require => Stage["post"]}


  $check_dummy_directory= generate("/bin/sh" ,"/etc/puppet/test/modules/mysql/files/dummy_directory.sh")

if(chop($check_dummy_directory)=="0")
 {
       # A temporary directory 'mysql_puppet' is created when MySQL module is executed the first time
       # This is a temporary fix until the cron script takes care of this functionality

        class{ "mysql::create_dummy_directory": stage =>pre } 
  
        # If Awesome_Purpose is either dbm/dbs/dbms/dbss, continue with MySQL Installation
        # Else Skip MySQL Insatallation
        # Awesome_Purpose => indicates if MySQL is to be installed or not. 
    
    $awesome_purpose = downcase($::awesome_purpose)
    if(($awesome_purpose=='fdbs') or( $awesome_purpose=='dbm') or ($awesome_purpose=='dbms') or($awesome_purpose=='dbss'))
      {

           # Check for installed MySQL packages
           # If present, terminate Install by sending an Email with appropriate message
           # Else continue with install..
         
           notice ("It is a Database Machine...Checking for Installed MySQL Packages ")
           $mysql_packages= generate("/bin/sh" ,"/etc/puppet/test/modules/mysql/files/mysql_test.sh")
           $result= chop($mysql_packages)
       
         if(chop($result) == "0")
           {
  
             # Check if /data/mysql is present
             # If present, terminate install by sending an Email with appropriate message
             # Else install and configure MySQL Install and send the result of install as Email

              notice("NO MySQL Packages found, Checking for /data/mysql...")
              $data_mysql_exists = generate("/bin/sh", "/etc/puppet/test/modules/mysql/files/data_mysql_test.sh")

              if(chop($data_mysql_exists)=="0")
              {
  
                 notice( "No /data/mysql found..Installing and configuring MySQL...")
                 class { "mysql::pre_install": stage =>pre }
                 class { "mysql::install": server=> $server, client=>$client, shared =>$shared, path => $path} 
                 class { "mysql::generate_my_cnf": email =>$email }
                 include  mysql::config, mysql::post_config,  mysql::service
                 class { "mysql::mysql_config": stage => post }
                 class { "mysql::email":install =>true, message =>" ",email =>$email,  stage=>email }
              }
              else
              {
  
                 notice ("/data/mysql found, Terminating Install...")
                 class  {"mysql::email":install =>false,message =>"/data/mysql found, terminating Install.",email =>$email,  stage=> email}
              }
           }
         else
         {
            notice ("MySQL Packages found. Terminating Install!!")
            class  {"mysql::email":install =>false,message =>"Pre-installed MySQL Packages found, terminating Install.",email =>$email,  stage=>email } 
         }
      }
  else
      {
         notice (" Not a Database Machine, Skipping MySQL Installation")
      }
 }

}
#end of class
