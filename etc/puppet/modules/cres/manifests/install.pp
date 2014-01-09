# Installation steps for the cres classes
class httpd::install {
    package { "httpd.x86_64":
        ensure => "present",
        ensure => "latest",
    }
}
