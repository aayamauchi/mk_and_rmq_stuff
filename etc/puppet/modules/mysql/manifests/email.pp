
# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $
# Sends email to the DBA indicating the result of MySQL Install
#   Loopback status information is appended to the message for the DBA to take the appropriate action  
#######################################################################################

# @ install - indicates if an attempt to install MySQL install was made or not
# @ message - contains reasons for terminating MySQL install, if an insyallation attempt is made, no message is passed 
# @ emamil  - Email address of the DBA supposed to get the results of puppet Install

class mysql::email ($install, $message,$email) {

if($install)
 {
  # check for loopback and generate an appropriate message for the DBA

    $loopback= generate("/bin/sh" ,"/etc/puppet/test/modules/mysql/files/loopback.sh")
    $loop=chop($loopback)
    
    if($loop=='0')
     {
       $loopback_msg="LOOPBACK IS NOT CONFIGURED "
     }
    else 
     {
       $loopback_msg="LOOPBACK IS CONFIGURED "
     }

  # if MySQL process is running => successful MySQL installation, send this message
    exec   {   "mysql_process_check_success":
               command   => "/bin/echo $loopback_msg but MySQL is  Successfully Installed  on $::fqdn . | mail -s 'Puppet MySQL Install on $::fqdn' $email",
               logoutput => true,
               require   => Class["mysql::service"],     
               onlyif    => "/bin/ps -ef | grep -i 'mysql'| grep -v grep ",
           }


  # if MySQL process is not running => Failure, send this message requesting the DBA to read the log files and to fix the issue
    exec   {   "mysql_process_check_failure":
               command   => "/bin/echo $loopback_msg and MySQL Installation failed. Please verify the Install   on $::fqdn . | mail -s 'Puppet MySQL Install on $::fqdn' $email",
               logoutput => true,
               require   => Class["mysql::service"],
               unless    => "/bin/ps -ef | grep -i 'mysql'| grep -v grep ",
           }
 }
else
 {
   exec   {   "mysql_process_check":
              command   => "/bin/echo $message  MySQL installation failed on $::fqdn .Please install MySQl manually!! | mail -s 'Puppet MySQL Install on $::fqdn' $email",
              logoutput => true,
          }


 } #END OF IF ELSE CONSTRUCT
 
}# END OF CLASS
