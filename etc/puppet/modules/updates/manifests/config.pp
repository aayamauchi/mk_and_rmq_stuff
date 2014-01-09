#
# $Id$
# $DateTime$
# $Change$
# $Author$
#
# config class for "updates" role
######################################################################

# Configuration steps for updates-www class
class updates::config::www::all {
    # Future config for all Linux Updater 2.0 machines
    File {
        owner => "updates",
        group => "updates",
        mode  => "644",
    }

    # Updater Run File Directory
    file { "/var/run/updater":
        ensure => directory,
        mode   => "755",
    }

    # Updater Configbuilder Directory
    file { "/usr/local/ironport/.configbuilder":
        ensure => directory,
        owner  => "root",
        group  => "wheel",
        mode   => "755",
    }

    # Updater SSL Cert Directory
    file { "/data/updater/ssl":
        ensure => directory,
        mode   => "755",
    }

    # Updater Log Directory
    file { "/data/var/log/updater":
        ensure => directory,
        mode   => "755",
    }

    # Updater Log Link
    file { "/var/log/updater":
        ensure => symlink,
        target => "/data/var/log/updater",
        mode   => "755",
    }

    file { "/etc/logrotate.d/nginx":
        source => "puppet:///modules/updates/logrotate.d/nginx",
        notify => Class["nginx::service::logrotate"]
    }

    file { "/etc/logrotate.d/uwsgi":
        source => "puppet:///modules/updates/logrotate.d/uwsgi",
        notify => Class["nginx::service::logrotate"]
    }
}

# ops-updates-www specific files
class updates::config::www::ops {
    # Loopback alias file.
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:0":
        source => "puppet:///modules/cacti/network/ifcfg-lo:0.ops",
    }
    # First deployment or whenever the file is updated, re-up the interface.
    exec { "/sbin/ifup lo:0":
        subscribe => File["/etc/sysconfig/network-scripts/ifcfg-lo:0"],
        refreshonly => true,
    }

    # Configbuilder default file
    file { "/usr/local/ironport/.configbuilder/_usr_local_ironport_updater_etc":
        source => "puppet:///modules/updates/configbuilder/_usr_local_ironport_updater_etc.ops",
    }
    # Run configbuilder when default file changes
    exec { "configure_updater":
       command      => "/usr/local/ironport/updater/bin/updater-configure.sh -v3 -s /usr/local/ironport/.configbuilder/",
        require     => "/usr/local/ironport/.configbuilder/_usr_local_ironport_updater_etc",
        subscribe   => Package['updater'],
        refreshonly => true,
    }
}

#eof
