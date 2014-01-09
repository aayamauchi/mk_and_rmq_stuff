#
# $Id: //sysops/main/puppet/test/modules/demo/manifests/disable.pp#3 $
# $DateTime: 2012/01/22 15:39:46 $
# $Change: 457653 $
# $Author: mhoskins $
#
# Sample module demonstrating some of Puppet's capabilities and file
# structure. Modules use a '::' delimited namespace, so this file
# would be accessed with a class name of "demo::disable".
#
# http://docs.puppetlabs.com/guides/modules.html
#
######################################################################

# check out inheritance!
class demo::disable inherits demo::enable {

	# Override syntax...
	Notify["demo_message"] { message => "We DISABLED something!" }

}

# eof
