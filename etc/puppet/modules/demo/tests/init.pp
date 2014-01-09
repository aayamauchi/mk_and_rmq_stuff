#
# $Id: //sysops/main/puppet/test/modules/demo/tests/init.pp#1 $
# $DateTime: 2012/01/22 15:04:32 $
# $Change: 457650 $
# $Author: mhoskins $
#
# Tests for the demo (init) class.
# http://docs.puppetlabs.com/guides/modules.html
#
######################################################################

# Declare with defaults
class { 'demo': }

# Pass in a value
class { 'demo':
	state => 'off',
}

# eof
