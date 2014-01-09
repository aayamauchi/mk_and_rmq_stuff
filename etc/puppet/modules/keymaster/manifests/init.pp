# This is the init.pp file for CRES related classes
# http://docs.puppetlabs.com/guides/language_guide.html#reserved-words--acceptable-characters
#

class keymaster {
	class { "keymaster::config::all": stage => main }
	if $::awesome_purpose == "app" {
                # Set up and turn on Apache
                class { "keymaster::config::app": stage => main }
	}
}
