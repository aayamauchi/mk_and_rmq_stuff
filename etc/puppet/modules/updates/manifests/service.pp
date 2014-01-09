#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/service.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# service classes for "updates" role
######################################################################

Service {
    ensure      => running,
    enable      => true,
    hasstatus   => true,
    hasrestart  => true
}

class updates::service::logrotate {
    service { "logrotate":
        require => Class["updates::config::www::all"]
    }
}

class updates::service::www {
    service { "httpd":
        require => Class["updates::config::www"]
    }
}

# eof
