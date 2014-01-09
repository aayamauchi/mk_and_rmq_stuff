# This is the init.pp file for CRES related classes
# http://docs.puppetlabs.com/guides/language_guide.html#reserved-words--acceptable-characters
#

class qa-cres-www {
    class { "cres::config::all": stage => main }
    class { "cres::config::www": stage => main }
    class { "cres::config::www::qa": stage => main }
    class { "cres::service::www::qa": stage => post }
}

class stage-cres-www {
    class { "cres::config::all": stage => main }
    class { "cres::config::www": stage => main }
    class { "cres::config::www::stage": stage => main }
    class { "cres::service::www::stage": stage => post }
}

class prod-cres-www {
    class { "cres::config::all": stage => main }
    class { "cres::config::www": stage => main }
    class { "cres::config::www::prod": stage => main }
    class { "cres::service::www::prod": stage => post }
}

class qa-cres-app {
    class { "cres::config::all": stage => main }
    class { "cres::config::app::qa": stage => main }
    class { "cres::service::app::qa": stage => post }
}

class stage-cres-app {
    class { "cres::config::all": stage => main }
    class { "cres::config::app::stage": stage => main }
    class { "cres::service::app::stage": stage => post }
}

class prod-cres-app {
    class { "cres::config::all": stage => main }
    class { "cres::config::app::prod": stage => main }
    class { "cres::service::app::prod": stage => post }
}
