#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/config.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# config class for shared "monitoring" data
######################################################################

# Configuration steps for puppet_www class
class monitoring::config {
	# Resource defaults
	File {
		owner => "root",
		group => "root",
		mode  => "644",
	}
	$monrepo = "[monitoring]
name=Monitoring Package Repo
baseurl=http://yum.ironport.com/yum/monitoring
enabled=1
gpgcheck=0"
	file { "/etc/yum.repos.d/monitoring.repo":
		ensure => present,
		content => $monrepo
	}
        file { "/etc/php.ini":
                source  => "puppet:///modules/cacti/php/php.ini",
        }
        file { "/usr/share/snmp/mibs/LM-SENSORS-MIB.txt":
                source  => "puppet:///modules/cacti/snmp/LM-SENSORS-MIB.txt"
        }
        file { "/etc/snmp/snmp.conf":
                source => "puppet:///modules/cacti/snmp/snmp.conf"
        }
        file { "/bin/ping":
                mode  => "4755"
        }
        $wmi = "domain=VM
username=nagios
password=BKidKOEXoW8s
"
	file { "/etc/cacti/":
		owner	=> nagios,
		group	=> apache,
		mode	=> 440,
		ensure	=> directory
	}

        file { "/etc/cacti/cactiwmi.pw":
                content => $wmi,
                owner   => nagios,
                group   => apache,
                mode    => 440
        }

        file { "/etc/at.allow":
                content => "nagios
apache",
        }
        
        file { "/etc/pam.d/atd":
                content => "auth        sufficient      pam_permit.so
account sufficient      pam_permit.so
session sufficient      pam_permit.so",
        }

        file { "/usr/bin/at":
                mode    => "4111"
        }

        file { "/usr/bin/wall":
                mode    => "4111"
        }

        user { "gearmand":
                ensure  => present,
                uid     => 390,
                gid     => nagios,
                home    => '/var/lib/gearmand'
        }


}

# eof
