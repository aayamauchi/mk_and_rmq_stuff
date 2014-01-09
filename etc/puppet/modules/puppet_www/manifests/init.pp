#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/init.pp#3 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# top level class for "puppet-www" role
######################################################################

# http://docs.puppetlabs.com/guides/language_guide.html#reserved-words--acceptable-characters
class puppet_www {

	# http://projects.puppetlabs.com/projects/puppet/wiki/Release_Notes#Run-Stages
	stage { [pre, post]: }
	Stage[pre] -> Stage[main] -> Stage[post]

	# or get standard run stages, etc. from the standard library
	#class { "stdlib": }

	# If you have a lot of custom logic, variable definitions, etc.
	# it may be more readable to contain them all in a params class.
	#class { "puppet_www::params": stage => pre }

	class { "puppet_www::pre": stage => pre }
	# Default run stage is main:
	# Within a run stage, use relationships like require and notify
	# to help with ordering and dependencies (see manifests).
	class { "puppet_www::install": }
	class { "puppet_www::service": }
	class { "puppet_www::config": }
	#class { puppet_www::post: stage => post }

}

# eof
