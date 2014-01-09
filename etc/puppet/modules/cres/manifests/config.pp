# Configuration steps for cres_www class
class cres::config::all {
    # Future config for all CRES machines
    File {
        owner => "root",
        group => "root",
        mode  => "644",
    }
}

# CRES Reverse Proxy Specific Settings - Stage
class cres::config::www {
    require => Class["httpd::install"],
    notify  => Class["cres::service::www::qa"],
    notify  => Class["cres::service::www::stage"],
    notify  => Class["cres::service::www::prod"],
    # Common Apache Config Files and Certificate(s)
    file { "/etc/httpd/conf/httpd.conf":
        source => "pupet:///modules/cres/httpd/conf/httpd.conf",
    }
    file { "/etc/httpd/conf.d/ssl.conf":
        source => "puppet:///modules/cres/httpd/conf.d/ssl.conf",
    }
    file { "/etc/httpd/conf/ssl.crt/verisignbundle_oct2010-2020.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/verisignbundle_oct2010-2020.crt",
    }

}

class cres::config::www::stage {
    require => Class["httpd::install"],
    notify  => Class["cres::service::www::qa"],
    notify  => Class["cres::service::www::stage"],
    notify  => Class["cres::service::www::prod"],
    # SSL Certificate Files
    file { "/etc/httpd/conf/ssl.crt/stage.res.cisco.com.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/stage.res.cisco.com.crt",
    }
    file { "/etc/httpd/conf/ssl.crt/test.res.cisco.com.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/test.res.cisco.com.crt",
    }
    # SSL CSR Files
    file { "/etc/httpd/conf/ssl.csr/stage.res.cisco.com.csr":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.csr/stage.res.cisco.com.csr",
    }
    file { "/etc/httpd/conf/ssl.csr/test.res.cisco.com.csr":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.csr/test.res.cisco.com.csr",
    # SSL Key Files
    }
    file { "/etc/httpd/conf/ssl.key/stage.res.cisco.com.key":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.key/stage.res.cisco.com.key",
    }
    file { "/etc/httpd.conf/ssl.key/test.res.cisco.com.key":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.key/test.res.cisco.com.key",
    }
    # Loop Back Interfaces
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:1":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:1-stage",
    }
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:2":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:2-stage",
    }
    # Apache Config Files
    file { "/etc/httpd/conf.d/vh-stage.conf":
        source => "puppet:///modules/cres/etc/httpd/conf.d/vh-stage.conf",
    }
    file { "/etc/httpd/conf.d/vh-stage-ssl.conf":
        source => "puppet:///modules/cres/etc/httpd/conf.d/vh-stage-ssl.conf",
}

class cres::config::www::qa {
    require => Class["httpd::install"],
    notify  => Class["cres::service::www::qa"],
    notify  => Class["cres::service::www::stage"],
    notify  => Class["cres::service::www::prod"],
    # SSL Certificate Files
    file { "/etc/httpd/conf/ssl.crt/qa.res.cisco.com.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/qa.res.cisco.com.crt",
    }
    file { "/etc/httpd/conf/ssl.crt/beta.res.cisco.com.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/beta.res.cisco.com.crt",
    }
    file { "/etc/httpd/conf/ssl.crt/dev.res.cisco.com.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/dev.res.cisco.com.crt",
    }
    # SSL CSR Files
    file { "/etc/httpd/conf/ssl.csr/qa.res.cisco.com.csr":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.csr/qa.res.cisco.com.csr",
    }
    file { "/etc/httpd/conf/ssl.csr/beta.res.cisco.com.csr":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.csr/beta.res.cisco.com.csr",
    }
    file { "/etc/httpd/conf/ssl.csr/dev.res.cisco.com.csr":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.csr/dev.res.cisco.com.csr",
    }
    # SSL Key Files
    file { "/etc/httpd/conf/ssl.key/qa.res.cisco.com.key":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.key/qa.res.cisco.com.key",
    }
    file { "/etc/httpd.conf/ssl.key/beta.res.cisco.com.key":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.key/beta.res.cisco.com.key",
    }
    file { "/etc/httpd.conf/ssl.key/dev.res.cisco.com.key":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.key/dev.res.cisco.com.key",
    }
    # Loop Back Interfaces
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:1":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:1-qa",
    }
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:2":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:2-qa",
    }
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:3":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:3-qa",
    }
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:4":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:4-qa",
    }
    # Apache Config Files
    file { "/etc/httpd/conf.d/vh-qa.conf":
        source => "puppet:///modules/cres/etc/httpd/conf.d/vh-qa.conf",
    }
    file { "/etc/httpd/conf.d/vh-qa-ssl.conf":
        source => "puppet:///modules/cres/etc/httpd/conf.d/vh-qa-ssl.conf",
}

class cres::config::www::prod {
    require => Class["httpd::install"],
    notify  => Class["cres::service::www::qa"],
    notify  => Class["cres::service::www::stage"],
    notify  => Class["cres::service::www::prod"],
    # SSL Certificate Files
    file { "/etc/httpd/conf/ssl.crt/res.cisco.com.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/res.cisco.com.crt",
    }
    file { "/etc/httpd/conf/ssl.crt/verify.res.cisco.com.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/verify.res.cisco.com.crt",
    }
    file { "/etc/httpd/conf/ssl.crt/pxmail.com.crt":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.crt/pxmail.com.crt",
    }
    # SSL CSR Files
    file { "/etc/httpd/conf/ssl.csr/res.cisco.com.csr":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.csr/res.cisco.com.csr",
    }
    file { "/etc/httpd/conf/ssl.csr/verify.res.cisco.com.csr":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.csr/verify.res.cisco.com.csr",
    }
    file { "/etc/httpd/conf/ssl.csr/pxmail.com.csr":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.csr/pxmail.com.csr",
    }
    # SSL Key Files
    file { "/etc/httpd/conf/ssl.key/res.cisco.com.key":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.key/res.cisco.com.key",
    }
    file { "/etc/httpd/conf/ssl.key/verify.res.cisco.com.key":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.key/verify.res.cisco.com.key",
    }
    file { "/etc/httpd/conf/ssl.key/pxmail.com.key":
        source => "puppet:///modules/cres/etc/httpd/conf/ssl.key/pxmail.com.key",
    }
    # Loop Back Interfaces
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:1":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:1-prod",
    }
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:2":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:2-prod",
    }
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:3":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:3-prod",
    }
    file { "/etc/sysconfig/network-scripts/ifcfg-lo:4":
        source => "puppet:///modules/cres/etc/sysconfig/network-scripts/ifcfg-lo:4-prod",
    }
    # Apache Config Files
    file { "/etc/httpd/conf.d/vh-prod.conf":
        source => "puppet:///modules/cres/etc/httpd/conf.d/vh-prod.conf",
    }
    file { "/etc/httpd/conf.d/vh-prod-ssl.conf":
        source => "puppet:///modules/cres/etc/httpd/conf.d/vh-prod-ssl.conf",
    }
}

class cres::config::app::qa {
    # THis is Reserved for the Future
}

class cres::config::app::stage {
    # This is Reserved for the Future
}

class cres::config::app::prod {
    # This is Reserved for the Future
}
