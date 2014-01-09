#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/install.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# main class for "monitoring" shared packages
######################################################################

class monitoring::main::packages {
    package { "MySQL-client-advanced":
	ensure => installed
    }

    # Install MySQL server on physical stage nodes.
    if $::awesome_environment == 'stage' and $virtual == 'physical' {
        package { "MySQL-server-advanced":
            ensure      => installed,
            require     => Package["MySQL-client-advanced"]
        }
    }

    # Third install pass, ops/monitoring repo
    $pkgs = [ "MySQL-shared-advanced", "MySQL-shared-compat-advanced",
	    "mysql-client-dummy", "httpd", "rrdtool", "boost141-program-options",
            "gearmand", "gearmand-server", "gearmand-devel", "mod_gearman",
            "libgearman", "pango", "cairo", "freetype", "fontconfig",
            "perl-XML-Parser", "php", "php-cli", "php-common", "php-devel",
            "php-ldap", "php-pdo", "php-snmp", "php-xml", "libffi",
            "atrpms", "cacti", "cacti-spine", "libyaml", "tftp",
            "net-snmp-perl-6.0.1", "net-snmp-utils", "perl-Socket6",
            "perl-Archive-Tar", "perl-Archive-Zip", "perl-Class-Accessor",
            "perl-Class-Inspector", "perl-Class-MethodMaker", "perl-Class-Singleton", 
            "perl-Compress-Raw-Bzip2", "perl-Compress-Raw-Zlib",
            "perl-Config-Tiny", "perl-Convert-BinHex", "perl-Crypt-SSLeay",
            "perl-Crypt-DES", "perl-Crypt-Rijndael", "perl-Data-UUID",
            "perl-DateTime", "perl-DateTime-Format-DateParse",
            "perl-Digest-CRC", "perl-Email-Address", "perl-ExtUtils-CBuilder",
            "perl-ExtUtils-ParseXS", "perl-File-Remove",
            "perl-IO-Compress-Base", "perl-IO-Compress-Bzip2",
            "perl-IO-Digest", "perl-IO-stringy", "perl-IO-Zlib",
            "perl-JSON", "perl-Locale-Maketext-Lexicon",
            "perl-Locale-Maketext-Simple", "perl-MailTools", "perl-DBD-MySQL",
            "perl-Math-Calc-Units", "perl-MIME-Lite", "perl-MIME-tools",
            "perl-Module-Build", "perl-Module-CoreList",
            "perl-Module-Install", "perl-Module-ScanDeps",
            "perl-Nagios-NSCA", "perl-Nagios-Plugin",
            "perl-Package-Constants", "perl-Params-Check", "perl-Params-Util",
            "perl-Params-Validate", "perl-PAR-Dist", "perl-Parse-CPAN-Meta",
            "perl-PerlIO-via-dynamic", "perl-SOAP-Lite", "perl-Spiffy",
            "perl-Test-Base", "perl-TimeDate", "perl-UUID", "perl-version",
            "perl-VMware", "perl-XML-LibXML", "perl-XML-LibXML-Common",
            "perl-XML-NamespaceSupport", "perl-XML-SAX", "perl-YAML",
            "perl-YAML-Tiny", "perl-Config-IniFiles", "php-pecl-json", "python26",
            "python26-BeautifulSoup", "python26-ClientCookie",
            "python26-crypto", "python26-distribute", "python26-dns",
            "python26-ldap", "python26-libs", "python26-mysqldb",
            "python26-nagiosplugin", "python26-paramiko", "python26-pydns",
            "python26-pyasn1", "python26-pysnmp", "python26-PyXML",
            "python26-PyYAML", "python26-simplejson", "python26-suds", "python26-pymongo",
            "rrdtool-perl", "rrdtool-php", "rrdtool-python", "uuid", "wmi",
            "nagios", "nagios-plugins-all", "nagios-common", "nsca", "nsca-client" ]
    package { $pkgs:
        ensure => installed,
        require => [ Class["monitoring::config"], Package["MySQL-client-advanced"] ]
    }

    # Cacti package installs bad logrotate file
    file { "/etc/logrotate.d/cacti":
        source => "puppet:///modules/cacti/cacti/logrotate",
        require => Package['cacti']
    }   

    Exec { path => "/bin" }
    # erroneous version issue with mod_ssl.  conflicing man files for the perl modules.
    exec { "rpm -i --nodeps http://prod-linbuild.vega.ironport.com/os/rhel/5.4/os/x86_64/Server/mod_ssl-2.2.3-31.el5.x86_64.rpm":
	unless => "rpm -q mod_ssl"
    }
    exec { "rpm -i --force http://yum.ironport.com/yum/monitoring/perl-Cwd-2.21-1.2.el5.rf.x86_64.rpm":
	unless => "rpm -q perl-Cwd"
    }
    exec { "rpm -i --force http://yum.ironport.com/yum/monitoring/perl-File-Spec-3.30-1.el5.rf.x86_64.rpm":
	unless => "rpm -q perl-File-Spec"
    }
    # install cacti overlay with pia, plugins, and internal scripts/resources
    exec { "rpm -i --force http://yum.ironport.com/yum/monitoring/cacti-pia-0.8.7i-6.x86_64.rpm":
        unless => "rpm -q cacti-pia",
        onlyif => "rpm -q cacti-0.8.7i-2.el5"
    }

}

# eof
