# configuration steps for keymaster class

class keymaster::config::all {
	File {
		owner => "keymaster",
		group => "keymaster",
		mode => "644",
	}

	file { "/data/var/log/keymaster/":
		ensure => directory,
		owner => "keymaster",
		group => "keymaster",
		mode => "644", 
	}

	file { "/var/log/keymaster/":
		ensure => link,
		target => "/data/var/log/keymaster",
	}

	file { "/data/keymaster/":
                ensure => directory,
                owner => "keymaster",
                group => "keymaster",
                mode => "644",
        }
	
	notify { "Environment is $awesome_environment": }

}

# Keymaster app server Specific Settlings
# currently assumes "test" = "stage"

class keymaster::config::app {

	file { "/var/run/keymaster/":
		ensure => directory,
		owner => "keymaster",
		group => "keymaster",
		mode => "644",
	}

	file { "/data/keymaster/sqlite":
		ensure => directory,
		owner => "keymaster",
		group => "keymaster",
		mode => "644",
	}
	
	file { "/usr/local/ironport/.configbuilder/":
		ensure => directory,
		owner => "root",
		group => "root",
		mode => "640",
	}

	file { "/data/keymaster/.python-eggs":
                ensure => directory,
                owner => "keymaster",
                group => "keymaster",
                mode => "644",
        }

	file { "/usr/local/ironport/.configbuilder/_usr_local_ironport_keymaster_etc":
		source => "puppet://modules/keymaster/config/_usr_local_ironport_keymaster_etc.$awesome_environment",
		owner => "keymaster",
		group => "keymaster",
		mode => "644",
	}

	file { "/etc/logrotate.d/nginx":
		source => "puppet://modules/keymaster/logrotate/nginx",
		owner => "root",
		group => "root",
		mode => "644",
	}

	file { "/etc/logrotate.d/uwsgi":
		source => "puppet://modules/keymaster/logrotate/uwsgi",
		owner => "root",
		group => "root",
		mode => "644",
	}

	# Loopback alias file. Pirated from cacti config.pp
        file { "/etc/sysconfig/network-scripts/ifcfg-lo:0":
                source => "puppet:///modules/keymaster/network/ifcfg-lo:0.$awesome_environment",
        }
	
        # First deployment or whenever the file is updated, re-up the interface.
        exec { "/sbin/ifup lo:0":
                subscribe => File["/etc/sysconfig/network-scripts/ifcfg-lo:0"],
                refreshonly => true
        }
	
}	
