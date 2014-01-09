#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/service.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# service classes for "monitoring" sub-role
######################################################################

class monitoring::service {
        Service {
                ensure      => running,
                enable      => true,
                hasstatus   => true,
                hasrestart  => true
        }

        service { "atd": }

}
