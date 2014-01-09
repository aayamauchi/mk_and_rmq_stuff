#
# $Id: //sysops/main/puppet/test/modules/puppet_www/manifests/pre.pp#2 $
# $DateTime: 2012/02/10 14:47:18 $
# $Change: 460969 $
# $Author: mhoskins $
#
# pre class for "cacti-www" role
######################################################################

# Pre-installation steps for cacti class
class cacti::pre {

	# Cleanup defunct snapdrive:
	#	service snapdrived stop
	#	service qlinstall-autoload stop
	#	chkconfig snapdrived off
	#	chkconfig qlinstall-autoload off
	#	rpm -e netapp.snapdrive
	#	rpm -e qla2xxx
	#service { [ "snapdrived", "qlinstall-autoload" ]:
	#	ensure    => stopped,
	#	enable    => false,
	#	hasstatus => true,
	#}
	#package { [ "netapp.snapdrive", "qla2xxx" ]:
	#	ensure  => absent,
	#	require => [ Service["snapdrived"], Service["qlinstall-autoload"] ],
	#}

}

# eof
