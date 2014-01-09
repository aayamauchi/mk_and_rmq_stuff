#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/config.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# config class for 'cacti-www' role
######################################################################

# Configuration steps for puppet_www class
class cacti::config::all {
	# Resource defaults
	File {
		owner => 'root',
		group => 'root',
		mode  => '644',
	}

	file { '/usr/share/cacti/include/config.php':
		source => 'puppet:///modules/cacti/cacti/config.php',
	}

        # Fails if we have a file declaration, and the nfs dir is already mounted.
        exec { '/bin/mkdir /data/rra':
                unless => '/usr/bin/test -d /data/rra'
        }
        file { '/usr/share/cacti/rra':
                ensure => link,
                target => '/data/rra'
        }
        # ssh keys for rsync
        file { '/var/www/.ssh/':
                ensure => directory,
                owner  => apache,
                mode   => '700'
        }
        file { '/var/www/.ssh/authorized_keys':
                source => 'puppet:///modules/cacti/ssh/id_rsa.pub',
                owner => apache,
                mode  => '444'
        }
        file { '/var/www/.ssh/id_rsa':
                source => 'puppet:///modules/cacti/ssh/id_rsa',
                owner => apache,
                mode  => '400'
        }
        file { '/var/www/.ssh/id_nagios':
                source => 'puppet:///modules/cacti/ssh/id_nagios',
                owner => apache,
                mode  => '400'
        }

        file { '/var/lib/cacti/scripts/':
                source => ['puppet:///modules/cacti/cacti/scripts/','puppet:///modules/nagios/ironport/nagios/sharedscripts/'],
                owner => apache,
                group => www,
                mode => 755,
                recurse => true,
                purge => false,
                sourceselect => all
        }
        file { '/var/lib/cacti/cli/':
                source => 'puppet:///modules/cacti/cacti/cli/',
                owner => apache,
                group => www,
                mode => 755,
                recurse => true,
                purge => false
        }
}

class cacti::config::app {
        file { '/etc/spine.conf':
                source  => 'puppet:///modules/cacti/cacti/spine.conf',
        }
	file { '/usr/share/cacti/spine.id':
		content	=> '-1',
		replace => false
	}

        file { '/usr/share/cacti/spine.sh':
                source  => 'puppet:///modules/cacti/cacti/spine.sh',
                mode    => '755'
        }
        cron { 'spine':
                command => '/usr/share/cacti/spine.sh',
                user    => apache,
                minute  => '*/5'
        }
        $rsync = '/usr/bin/rsync -az --stats ops-cacti-db-m1.vega.ironport.com::cache /tmp/vmware_cache >/dev/null 2>&1'
        cron { 'vmware cache rsync':
                command => $rsync,
                user    => apache,
                minute  => '*/4'
        }
        file { '/usr/share/cacti/png':
                ensure  => directory,
                owner   => apache,
                group   => www
        }
}

class cacti::config::www {
	# clean up conf.d
	tidy { '/etc/httpd/conf.d':
		matches => 'proxy_ajp.conf',
		recurse => 1
	}
	# Managed files
	file { '/etc/httpd/conf/httpd.conf':
		source  => 'puppet:///modules/cacti/apache/httpd.conf',
		notify  => Class['cacti::service::httpd'],
	}
	file { '/etc/httpd/conf.d/cacti.conf':
		source  => 'puppet:///modules/cacti/apache/cacti.conf',
		notify  => Class['cacti::service::httpd'],
	}
        file { '/etc/httpd/conf.d/ssl.conf':
                source  => 'puppet:///modules/cacti/apache/ssl/ssl.conf',
                notify  => Class['cacti::service::httpd']
        }
        file { '/etc/pki/tls/certs/cacti-cisco.ironport.com.crt':
                source  => 'puppet:///modules/cacti/apache/ssl/cacti-cisco.ironport.com.crt',
                notify  => Class['cacti::service::httpd']
        }
        file { '/etc/pki/tls/private/cacti-cisco.ironport.com.key':
                source  => 'puppet:///modules/cacti/apache/ssl/cacti-cisco.ironport.com.key',
                notify  => Class['cacti::service::httpd']
        }
        file { '/etc/pki/tls/private/Thawte_2012_SSL_CA_Bundle.crt':
                source  => 'puppet:///modules/cacti/apache/ssl/Thawte_2012_SSL_CA_Bundle.crt',
                notify  => Class['cacti::service::httpd']
        }
	file { '/var/www/html/index.html':
		source  => 'puppet:///modules/cacti/htdocs/index.html',
	}
	# Loopback alias file.
	file { '/etc/sysconfig/network-scripts/ifcfg-lo:0':
		source => 'puppet:///modules/cacti/network/ifcfg-lo:0'
	}
	# First deployment or whenever the file is updated, re-up the interface.
	exec { '/sbin/ifup lo:0':
		subscribe => File['/etc/sysconfig/network-scripts/ifcfg-lo:0'],
		refreshonly => true
	}

        $rsync = '/usr/bin/rsync -az --stats ops-cacti-db-m1.vega.ironport.com::cache /tmp/vmware_cache >/dev/null 2>&1'
        cron { 'vmware cache rsync':
                command => $rsync,
                user    => apache,
                minute  => '*/4'
        }
        mount { '/data/rra':
                device => 'ops-cacti-db-m1.vega.ironport.com:/data/rra',
                fstype => 'nfs',
                ensure => 'mounted',
                atboot => true,
                options => 'defaults'
        }
}

class cacti::config::dbs {
        $rsync = '/usr/share/cacti/cli/backup_cacti_rra.sh'
        cron { 'rrd rsync':
                command => $rsync,
                user    => apache,
                minute  => '20',
                hour    => '*/4'
        }
}

class cacti::config::dbm {
	$nfs = '/data/rra *-cacti-www*.ironport.com(rw) *-cacti-app*.ironport.com(ro) *-mon-*.ironport.com(ro) *-asdb-*.ironport.com(ro)'
	file { '/etc/exports':
		content => $nfs,
		notify  => Class['cacti::service::nfs']
	}
        file { '/usr/share/cacti/boost.sh':
                source  => 'puppet:///modules/cacti/cacti/boost.sh',
                mode    => '755'
        }
        cron { 'boost':
                command => '/usr/share/cacti/boost.sh',
                user    => apache
        }
        file { '/etc/rsyncd.conf':
                source  => 'puppet:///modules/cacti/rsync/rsyncd.conf'
        }
        file { '/etc/xinetd.d/rsync':
                source  => 'puppet:///modules/cacti/rsync/rsync',
                notify  => Class['cacti::service::xinetd']
        }
        cron { 'loadbalancer':
                command => 'cd /usr/share/cacti; cat cli/loadbalance.sql | /usr/bin/mysql -u cactiuser -pcact1pa55 -h localhost cacti >> log/loadbalance.log 2>&1',
                user    => apache,
                minute  => '4-59/5'
        }
}
# eof
