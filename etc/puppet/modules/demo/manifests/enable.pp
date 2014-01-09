#
# $Id: //sysops/main/puppet/test/modules/demo/manifests/enable.pp#3 $
# $DateTime: 2012/01/22 15:39:46 $
# $Change: 457653 $
# $Author: mhoskins $
#
# Sample module demonstrating some of Puppet's capabilities and file
# structure. Modules use a '::' delimited namespace, so this file
# would be accessed with a class name of "demo::enable".
#
# http://docs.puppetlabs.com/guides/modules.html
#
######################################################################

# classes don't have to use parameters...
class demo::enable {

	# Send a message to the client...
	notify { "demo_message": message => "We ENABLED something!" }

}

# eof
