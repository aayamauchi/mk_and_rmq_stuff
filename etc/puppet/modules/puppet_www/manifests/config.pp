#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/config.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# config class for "puppet-www" role
######################################################################

# Configuration steps for puppet_www class
class puppet_www::config {

	# Remove default boilerplate
	tidy { "/etc/httpd/conf.d":
		age     => "0",
		before => File["/etc/httpd/conf/httpd.conf"],
	}

	# Resource defaults
	File {
		owner => "root",
		group => "root",
		mode  => "644",
	}

	# Managed files
	file { "/etc/httpd/conf/httpd.conf":
		source  => "puppet:///modules/puppet_www/apache/httpd.conf",
		require => Class["puppet_www::install"],
		notify  => Class["puppet_www::service"],
	}

	file { "/var/www/html/index.html":
		source  => "puppet:///modules/puppet_www/htdocs/index.html",
		require => Class["puppet_www::install"],
	}

	file { "/etc/cron.d/puppet-www.cron":
		source  => "puppet:///modules/puppet_www/puppet-www.cron",
		require => Class["puppet_www::install"],
		notify  => Class["puppet_www::service"],
	}

}

# eof
