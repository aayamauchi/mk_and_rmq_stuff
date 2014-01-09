# Service classes for CRES
Service {
        ensure      => running,
        enable      => true,
        hasstatus   => true,
        hasrestart  => true
}

class cres::service::www::qa {
    service { "httpd":
        require => Class["httpd::install"]
        require => Class["cres::config::www::qa"]
        require => Class["cres::config::www"]
    }
}

class cres::service::www::stage {
    service { "httpd":
        require => Class["httpd::install"]
        require => Class["cres::config::www::stage"]
        require => Class["cres::config::www"]
    }
}

class cres::service::www::prod {
    service { "httpd":
        require => Class["httpd::install"]
        require => Class["cres::config::www::prod"]
        require => Class["cres::config::www"]
    }
}
