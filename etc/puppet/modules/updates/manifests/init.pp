# This is the init.pp file for Updates related classes
# http://docs.puppetlabs.com/guides/language_guide.html#reserved-words--acceptable-characters
#

class ops-updates-www {
    class { "updates::config::www": stage => pre }
    class { "updates::config::www::ops": stage => main }
    class { "updates::service::www::ops": stage => post }
}

class stage-updates-www {
    class { "updates::config::www": stage => pre }
    class { "updates::config::www::stage": stage => main }
    class { "updates::service::www::stage": stage => post }
}

class int-updates-www {
    class { "updates::config::www": stage => pre }
    class { "updates::config::www::int": stage => main }
    class { "updates::service::www::int": stage => post }
}

class prod-updates-www {
    class { "updates::config::www": stage => pre }
    class { "updates::config::www::prod": stage => main }
    class { "updates::service::www::prod": stage => post }
}
