#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/config.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# config class for "nagios" role
######################################################################

# Configuration steps for nagios::config class
class nagios::config {
	# Resource defaults
	File {
		owner => "nagios",
		group => "nagios",
		mode  => "644",
	}

        file { "/etc/nagios":
                ensure => directory,
        }

        file { [ "/usr/local/nagios", "/usr/local/nagios/bin/", "/usr/local/nagios/var/",
                    "/usr/local/nagios/var/tmp/", "/usr/local/nagios/var/status/",
                    "/usr/local/nagios/var/spool/", "/usr/local/nagios/var/spool/checkresults/",
                    "/usr/local/nagios/var/rw/", "/usr/local/nagios/notification_spool/",
                    "/usr/local/nagios/var/log/", 
                    "/usr/local/nagios/var/objects/", "/data/nagios-archives/" ]:
                ensure => directory
        }

        file { "/usr/local/nagios/etc":
                ensure => link,
                target => "/etc/nagios"
        }
        file { "/usr/local/nagios/var/archives":
                ensure  => link,
                target  => "/data/nagios-archives"
        }

        exec { 'bash -c "ln -s /etc/nagios /usr/local/nagios/etc-`hostname | sed -e s/.sco.cisco.com// -e s/.ironport.com//`"':
                unless  => 'bash -c "[ -e /usr/local/nagios/etc-`hostname | sed -e s/.sco.cisco.com// -e s/.ironport.com//` ]"',
                path    => '/bin:/usr/bin:/usr/local/bin'
        }

        file { "/usr/local/nagios/bin/nagios":
                ensure => link,
                target => "/usr/sbin/nagios"
        }

        file { "/usr/local/nagios/bin/nagiostats":
                ensure => link,
                target => "/usr/bin/nagiostats"
        }

        file { "/usr/local/nagios/bin/nsca":
                ensure => link,
                target => "/usr/sbin/nsca"
        }

        file { "/usr/local/nagios/bin/send_nsca":
                ensure => link,
                target => "/usr/sbin/send_nsca"
        }

        file { "/usr/local/nagios/libexec":
                ensure => link,
                target => "/usr/lib64/nagios/plugins/",
                force => true
        }

        file { "/usr/local/ironport/":
                ensure  => directory
        }

        file { "/usr/local/ironport/nagios/":
                ensure  => directory
        }

        file { "/usr/local/ironport/nagios/bin/":
                ensure  => directory,
                recurse => true,
                mode    => 755,
                purge   => false,
                source  => "puppet:///modules/nagios/ironport/nagios/bin/"
        }

        file { "/usr/local/ironport/nagios/var/":
                ensure  => directory,
                recurse => true,
                mode    => 750,
                purge   => false,
                source  => "puppet:///modules/nagios/ironport/nagios/var/"
        }

        file { "/usr/local/ironport/nagios/customplugins/":
                ensure  => directory,
                sourceselect => all,
                recurse => true,
                mode    => 755,
                purge   => false,
                source  => ["puppet:///modules/nagios/ironport/nagios/customplugins/","puppet:///modules/nagios/ironport/nagios/sharedscripts/"]
        }

        file { "/usr/local/ironport/nagios/ssl/":
                ensure  => directory,
                recurse => true,
                mode    => 700,
                purge   => false,
                source  => "puppet:///modules/nagios/ironport/nagios/ssl/"
        }

        # mail input handlers
        file { "/usr/local/ironport/nagios/mail/":
                ensure  => directory,
                recurse => true,
                recurselimit => 1,
                mode    => 755,
                purge   => false,
                source  => "puppet:///modules/nagios/ironport/nagios/mail/"
        }
        file { "/etc/procmailrcs":
                ensure  => directory,
                owner   => "root",
                group   => "wheel"
        }
        file { "/etc/procmailrcs/ces-alert.rc":
                ensure  => present,
                force   => true,
                source  => "puppet:///modules/nagios/ironport/nagios/mail/CES_Alert/procmailrc"
        }
        file { "/etc/procmailrcs/sysops-alert.rc":
                ensure  => present,
                force   => true,
                source  => "puppet:///modules/nagios/ironport/nagios/mail/Sysops_Alert/procmailrc"
        }
        file { "/etc/aliases":
                ensure  => present,
                owner   => "root",
                group   => "mail",
                source  => "puppet:///modules/nagios/etc/aliases"
        }
        file { "/usr/bin/procmail":
                ensure  => present,
                owner   => root,
                group   => mail,
                mode    => 04755
        }

        # autoack
        file { "/usr/local/var/nagios/.procmailrc":
                ensure  => present,
                mode    => 644,
                recurse => true,
                purge   => false,
                source  => "puppet:///modules/nagios/nagios_homedir/.procmailrc"
        }
        file { "/usr/local/var/nagios/mail/":
                ensure  => directory,
                mode    => 755,
                recurse => true,
                purge   => false,
                source  => "puppet:///modules/nagios/nagios_homedir/mail/"
        }
        file { "/usr/local/var/nagios/autoack/":
                ensure  => directory,
                mode    => 755,
                recurse => true,
                purge   => false,
                source  => "puppet:///modules/nagios/nagios_homedir/autoack/"
        }


        # xinetd
        $nsca = "nsca           5667/tcp   #Nagios Service Check Aggregator"
        file_line { "nsca_service":
                path    => "/etc/services",
                line    => $nsca
        }
        file { "/etc/xinetd.d/nsca":
                ensure  => present,
                owner   => root,
                group   => wheel,
                source  => "puppet:///modules/nagios/etc/xinetd.d/nsca",
                notify  => Class["nagios::service::xinetd"]
        }

        # snmptraps
        file { "/etc/snmp/":
                ensure  => directory,
                purge   => false,
                recurse => true,
                owner   => "root",
                group   => "wheel",
                mode    => 750,
                source  => "puppet:///modules/nagios/etc/snmp/",
                notify  => Class["nagios::service::snmptrapd"]
        }

        # mail aliases
        exec { '/usr/bin/newaliases':
                unless  => '[ /etc/aliases.db -nt /etc/aliases ]',
                path    => '/bin:/usr/bin:/usr/local/bin',
                require => File['/etc/aliases']
        }

        # handlers
        file { "/usr/local/ironport/nagios/event_handler/":
                ensure  => directory,
                recurse => true,
                mode    => 755,
                purge   => false,
                source  => "puppet:///modules/nagios/ironport/nagios/event_handler/"
        }
        file { "/usr/local/ironport/nagios/notification_handler/":
                ensure  => directory,
                recurse => true,
                mode    => 755,
                purge   => false,
                source  => "puppet:///modules/nagios/ironport/nagios/notification_handler/"
        }

        # notification templates
        file { "/usr/local/nagios/notification_templates/":
                ensure  => directory,
                recurse => true,
                mode    => 755,
                purge   => true,
                source  => "puppet:///modules/nagios/nagios/notification_templates/"
        }

        # Symlinks to retain compatiblity with FreeBSD Config deployment.
        file { "/var/log/nagios/objects.precache":
                ensure  => link,
                force   => true,
                target  => "/usr/local/nagios/var/objects.precache"
        }

        file { "/var/log/nagios/objects.cache":
                ensure  => link,
                force   => true,
                target  => "/usr/local/nagios/var/objects.cache"
        }

        file { "/var/log/nagios/status.dat":
                ensure  => link,
                force   => true,
                target  => "/usr/local/nagios/var/status/status.log"
        }

        file { "/usr/local/nagios/share/":
                ensure  => link,
                force   => true,
                target  => "/usr/share/nagios/html/"
        }

        file { "/var/log/nagios/rw/":
                ensure  => link,
                force   => true,
                target  => "/usr/local/nagios/var/rw/",
                require => File['/usr/local/nagios/var/rw/']
        }

        # Gearman
        file { "/var/lib/gearmand/":
                ensure  => directory,
                owner   => gearmand,
                mode    => 755
        }
        file { "/etc/mod_gearman/mod_gearman_worker.conf":
                ensure  => link,
                target  => '/etc/nagios/gearman.cfg'
        }

        # Apache configuration
        file { "/etc/httpd/conf/httpd.conf":
                ensure  => present,
                source  => "puppet:///modules/nagios/apache/httpd.conf"
        }
        file { "/etc/httpd/conf.d/nagios.conf":
                ensure  => present,
                source  => "puppet:///modules/nagios/apache/nagios.conf"
        }
        file { "/etc/pki/":
                ensure  => directory,
                owner   => root,
                group   => root,
                mode    => 755,
                recurse => true,
                purge   => false,
                source  => "puppet:///modules/nagios/etc/pki/"
        }
        # Mobile ui.  Consider enabling APC for better performance
        file { "/usr/local/nagios/mobile/":
                ensure  => directory,
                mode    => 755,
                recurse => true,
                purge   => true,
                source  => "puppet:///modules/nagios/mobile/"
        }
        file { "/etc/httpd/conf.d/nagiosmobile_apache.conf":
                ensure  => present,
                source  => "puppet:///modules/nagios/mobile/nagiosmobile_apache.conf"
        }

        # Apply exfoliate skin and custom images and updated index.php
        file { "/usr/share/nagios/html/":
                ensure  => directory,
                recurse => true,
                purge   => false,
                source  => "puppet:///modules/nagios/apache/nagios/"
        }

        file { "/usr/lib64/nagios/cgi-bin/":
                ensure  => directory,
                recurse => true,
                purge   => false,
                mode    => 755,
                source  => "puppet:///modules/nagios/apache/nagios-cgi/"
        }

        # ssh keys
        file { "/usr/local/var/nagios/.ssh/":
                ensure  => directory,
                mode    => "700",
        }
        file { "/usr/local/var/nagios/.ssh/authorized_keys":
                source  => "puppet:///modules/nagios/ssh/id_rsa.pub",
                mode    => 600
        }
        file { "/usr/local/var/nagios/.ssh/id_rsa.pub":
                source  => "puppet:///modules/nagios/ssh/id_rsa.pub",
                mode    => 600
        }

        file { "/usr/local/var/nagios/.ssh/id_rsa":
                source  => "puppet:///modules/nagios/ssh/id_rsa",
                mode    => 600
        }

        file { "/usr/local/var/nagios/.ssh/config":
                content => "StrictHostKeyChecking=no"
        }



        # Ramdisk mounts for purrrrformance, and loopback alias (if master)
        if $boardproductname == 'UCSC-BSE-SFF-C200' {
            # Master node.  
            # Loopback alias file.
            file { "/etc/sysconfig/network-scripts/ifcfg-lo:0":
                    source => "puppet:///modules/nagios/network/ifcfg-lo:0"
            }
            # First deployment or whenever the file is updated, re-up the interface.
            exec { "/sbin/ifup lo:0":
                    subscribe => File["/etc/sysconfig/network-scripts/ifcfg-lo:0"],
                    refreshonly => true
            }

            # just under a month of "live" storage for faster reports
            # day-to-day log approx 1gb as of 2012-10-03
            mount { "/usr/local/nagios/var/log":
                    ensure  => mounted,
                    device  => tmpfs,
                    fstype  => tmpfs,
                    options => "size=30g",
                    require => File['/usr/local/nagios/var/log/']
            }
            # objects ramdisk for faster master startup.
            # files approx 55mb each as of 2012-10-03
            mount { "/usr/local/nagios/var/objects":
                    ensure  => mounted,
                    device  => tmpfs,
                    fstype  => tmpfs,
                    options => "size=500m",
                    require => File['/usr/local/nagios/var/objects/']
            }
            # log retention
            cron { "copy ramdisk logfiles to physical storage":
                    command => "/usr/bin/rsync /usr/local/nagios/var/log/ /data/nagios-archives/",
                    minute  => "*/20"
            }
        } elsif $boardproductname == '0H603H' {
            mount { "/usr/local/nagios/var/log":
                    ensure  => mounted,
                    device  => tmpfs,
                    fstype  => tmpfs,
                    options => "size=10g",
                    require => File['/usr/local/nagios/var/log/']
            }
            # objects ramdisk for faster master startup.
            # files approx 55mb each as of 2012-10-03
            mount { "/usr/local/nagios/var/objects":
                    ensure  => mounted,
                    device  => tmpfs,
                    fstype  => tmpfs,
                    options => "size=500m",
                    require => File['/usr/local/nagios/var/objects/']
            }
        } else {
            # only enable auto-restart on non-master.
            cron { "automatic restart on config update":
                    command => "/usr/local/ironport/nagios/bin/restart-nagios.sh > /dev/null 2>&1",
                    user    => "root",
                    minute  => "*/5"
            }
        }

        # log clearing
        cron { "purge older logfiles from ramdisk":
                command => "/usr/bin/find /usr/local/nagios/var/log -mtime +16 -exec rm {} \;",
                minute  => "5",
                hour    => "0"
        }
        # each file approx 50mb as of 2012-10-03
        mount { "/usr/local/nagios/var/status":
                ensure  => mounted,
                device  => tmpfs,
                fstype  => tmpfs,
                options => "size=250m",
                require => File['/usr/local/nagios/var/status/']
        }

        mount { "/usr/local/nagios/var/spool/checkresults":
                ensure  => mounted,
                device  => tmpfs,
                fstype  => tmpfs,
                options => "size=250m",
                require => File['/usr/local/nagios/var/spool/checkresults/']
        }

        mount { "/usr/local/nagios/var/tmp":
                ensure  => mounted,
                device  => tmpfs,
                fstype  => tmpfs,
                options => "size=250m",
                require => File['/usr/local/nagios/var/tmp/']
        }
        
        mount { "/usr/local/nagios/notification_spool":
                ensure  => mounted,
                device  => tmpfs,
                fstype  => tmpfs,
                options => "size=250m",
                require => File['/usr/local/nagios/notification_spool']
        }

        cron { "nagios to cacti stats export":
                command => "/usr/local/ironport/nagios/bin/nagiostats_cacti.sh > /tmp/nagiostats_cacti.out 2>/dev/null",
                user    => "root",
                minute  => "*/5"
        }

        cron { "long term log storage":
                command => "/usr/bin/rsync /usr/local/nagios/var/log/ /data/nagios-archives/ >/dev/null 2>&1",
                minute  => "50"
        }
}

# eof
