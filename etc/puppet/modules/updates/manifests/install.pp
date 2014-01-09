#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/install.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# install class for "updates" role
######################################################################

# Installation steps for updates::www class
class updates::www::install {

	# Install packages using yum provider
	package { "updater":
		ensure => installed,
	}

}

# eof
