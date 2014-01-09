# $DateTime: 2012/03/07 20:27:57 $
# $Change: 1 $
# $Author: ajvijaya $

# Starts MySQL Service
# Requires post_config class

######################################################################


class mysql::service {

service {       [ "mysql" ]:
		ensure     => running,
	#	enable     => true,
		hasstatus  => true,
		hasrestart => true,
		require => Class["mysql::post_config"],
                
	}


} 
