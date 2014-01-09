#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/init.pp#3 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# top level class for "cacti" role
######################################################################

# http://docs.puppetlabs.com/guides/language_guide.html#reserved-words--acceptable-characters
class cacti {

	class { "cacti::pre": stage => pre }
	# Default run stage is main:
	# Within a run stage, use relationships like require and notify
	# to help with ordering and dependencies (see manifests).
	class { "cacti::config::all": stage => main }
	if $::awesome_purpose == "www" {
		# Set up and turn on Apache
		class { "cacti::config::www": stage => main }
		class { "cacti::service::httpd": stage => post }
	} elsif $::awesome_purpose == "dbs" {
		# Set up RRD copy
                class { "cacti::config::dbs": stage => main }
	} elsif $::awesome_purpose == "dbm" {
                # Set up boost export and RRD share
		class { "cacti::config::dbm": stage => main }
		class { "cacti::service::nfs": stage => post }
		class { "cacti::service::xinetd": stage => post }
	} elsif ($::awesome_purpose == "app" or $::awesome_tag_spine == "true") {
		# Set up Spine cron.
                class { "cacti::config::app": stage => main }
	}
	#class { cacti::post: stage => post }

}

# eof
