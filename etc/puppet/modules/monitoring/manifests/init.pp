#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/init.pp#3 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# top level class for "cacti-www" role
######################################################################

# http://docs.puppetlabs.com/guides/language_guide.html#reserved-words--acceptable-characters
class monitoring {

	# If you have a lot of custom logic, variable definitions, etc.
	# it may be more readable to contain them all in a params class.
	#class { "cacti_www::params": stage => pre }

	#class { "cacti_www::pre": stage => pre }
	# Default run stage is main:
	# Within a run stage, use relationships like require and notify
	# to help with ordering and dependencies (see manifests).
	class { "monitoring::config": stage => pre }
	class { "monitoring::main::packages": stage => pre }
	class { "monitoring::service": }
	#class { "monitoring::config": }
	#class { cacti_www::post: stage => post }

}

# eof
