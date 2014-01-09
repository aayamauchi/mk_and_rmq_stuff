#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/install.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# install class for "puppet-www" role
######################################################################

# Installation steps for puppet_www class
class puppet_www::install {

	# Install packages using yum provider
	package { "httpd":
		ensure => installed,
	}

	package { "createrepo":
		ensure => installed,
	}

}

# eof
