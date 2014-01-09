#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/service.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# service classes for "nagios" role
######################################################################

Service {
        ensure      => running,
        enable      => true,
        hasstatus   => true,
        hasrestart  => true,
        require => Class["nagios::config"]
}

class nagios::service::nagios{
        service { "nagios": }
}

class nagios::service::snmptrapd{
        service { "snmptrapd": }
}

class nagios::service::xinetd{
        service { "xinetd": }
}

class nagios::service::gearmand{
        service { "gearmand": }
}
class nagios::service::mod_gearman_worker{
        service { "mod_gearman_worker": }
}

# eof
