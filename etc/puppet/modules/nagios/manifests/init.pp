#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/init.pp#3 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# top level class for "nagios" role
######################################################################

# http://docs.puppetlabs.com/guides/language_guide.html#reserved-words--acceptable-characters
class nagios {

	# or get standard run stages, etc. from the standard library
	#class { "stdlib": }

	# If you have a lot of custom logic, variable definitions, etc.
	# it may be more readable to contain them all in a params class.
	#class { "nagios::params": stage => pre }

	# Default run stage is main:
	# Within a run stage, use relationships like require and notify
	# to help with ordering and dependencies (see manifests).
	class { "nagios::config": stage => pre }
        class { "nagios::service::nagios": stage => post }
        class { "nagios::service::snmptrapd": stage => post }
        class { "nagios::service::xinetd": stage => post }
}

# eof
