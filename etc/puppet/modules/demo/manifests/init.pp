#
# $Id: //sysops/main/puppet/test/modules/demo/manifests/init.pp#3 $
# $DateTime: 2012/01/22 15:39:46 $
# $Change: 457653 $
# $Author: mhoskins $
#
# Sample module demonstrating some of Puppet's capabilities and file
# structure. Each module should have an 'init.pp' file with a class
# matching the module's name so the autoloader can find it.
#
# http://docs.puppetlabs.com/guides/modules.html
#
######################################################################

# classes can take parameters, with or without default values...
class demo($state='on', $anotherone='') {

	# Send a message to the client...
	notify { "hello_world": message => "Hello World!" }

	# Populate a file from an ERB template...
	file { "/tmp/demo.puppet":
		ensure  => present,
		content => template("demo/sample_template.erb"),
		owner   => "0",
		group   => "0",
		# Best practice says always include ',' at the end
		# to avoid easy copy/paste errors later...
		mode    => "0644",
	}

	# Run a command once; use the environment...  This converges
	# by only running if expected output doesn't exist.
	exec { "onetime":
		path        => "/bin",
		command     => 'echo "$FOO" > /tmp/norun',
		creates     => "/tmp/norun",
		environment => [ "FOO=bar baz", "BAR=foo" ],
	}

	# Commands run every time if not careful...
	exec { "repeats":
		path    => "/bin",
		command => "cat /tmp/demo.puppet /tmp/norun",
		# Metaprameters setup relationships
		require => [ File["/tmp/demo.puppet"], Exec["onetime"] ] ,
	}

	# Install a package; uses configured yum repos...
	#package { "mypackage": ensure => present, }

	# Manage a service...
	#service { "myservice":
	#	ensure => 'running',
	#	enable => 'true',
	#}

	# Use some logic
	# http://docs.puppetlabs.com/guides/language_guide.html#conditionals
	case $state {
		'off': {
			include demo::disable
		}
		default: {
			include demo::enable
		}
	}
}

# eof
