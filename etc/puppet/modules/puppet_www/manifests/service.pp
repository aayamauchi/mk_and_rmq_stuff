#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/service.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# service class for "puppet-www" role
######################################################################

class puppet_www::service {

	service { [ "httpd", "crond" ]:
		ensure     => running,
		enable     => true,
		hasstatus  => true,
		hasrestart => true,
		require => Class["puppet_www::config"],
	}

}

# eof
