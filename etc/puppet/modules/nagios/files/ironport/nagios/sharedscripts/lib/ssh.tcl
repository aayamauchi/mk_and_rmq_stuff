lappend auto_path [file dirname [info script]]

namespace eval ::opsssh {
	namespace export opsssh
	variable version 0.2
	variable ssh_idx 0
	# special random string with means NULL password
	variable null_password {eI]Ja26,<fSWjoB$R-gn/&:PgG9xHRH]qQ_5zmY&ZSGdYWfMc9F&a(h7nv;L1Xqn}
}

package provide opsssh $::opsssh::version
# ::opsssh::openssh -- create namespace with ssh client parameters
#
# Create new namespace for ssh client and fill specified values to it.
#
# Arguments:
# ?-retry retrycount                  - numeric with ssh command
#           retry attempts before error
# ?-command sshclientcommandname      - string with ssh CLI
#           utility name (default ssh)
# ?-commandargs sshclientCLIarguments - string with ssh CLI
#           utility parameters
# ?-host sshhostname                  - string with ssh server hostname
# ?-port sshport                      - numeric with ssh server port
# ?-key keyfile                       - sprint with path to secret key file
# ?-username sshusername              - string with ssh username
# ?-password sshpassword              - string with ssh password
# ?--                                 - flag for stop parsing arguments
#
# Side Effects:
# Create new namespace opsssh::sshN with ssh client settings
# variables.
#
# Results:
# string with new ssh client namespace name
proc ::opsssh::openssh {args} {
	variable ssh_idx
	incr ssh_idx
	namespace eval ::opsssh::ssh[set ssh_idx] {
		variable retry 1
		variable command "ssh"
		variable commandargs "-o StrictHostKeyChecking=no"
		variable host "localhost"
		variable port 22
		variable password
	}
	variable null_password
	set ::opsssh::ssh[set ssh_idx]::password $null_password
	set args $args
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			{-retry} -
			{-command} -
			{-commandargs} -
			{-host} -
			{-port} -
			{-key} -
			{-username} -
			{-password} {
				set ::opsssh::ssh[set ssh_idx]::[string trimleft $arg "-"] [lindex $args 1]
				set args [lrange $args 2 end]
			}
		}
	}
	return "ssh[set ssh_idx]"
}
# ::opsssh::closessh -- delete namespace with ssh client parameters
#
# Delete specified namespace with ssh parameters
#
# Arguments:
# sshId   - string with ssh client namespace name
#
# Side Effects:
# Delete appropriate ssh namespace opsssh::sshN with ssh client
# settings variables.
#
# Results:
# 0 when function is worked successfully
# -1 when log namespace does not exists
proc ::opsssh::closessh {sshId} {
	if [namespace exists ::opsssh::[set sshId]] {
		namespace delete ::opsssh::[set sshId]
		return 0
	} else {
		return 1
	}
}
# ::opsssh::ssh -- run command on remote SSH server.
#
# Run command on specified SSH server and return unformated result.
# When ssh client namespace is specified this function get
# parameters for ssh client from specified namespace and other
# optional arguments overrides appropriate values.
# When ssh client namespace is not specified you must define all
# other optional arguments.
#
# Arguments:
# ?-sshId                             - string with ssh client
#           namespace name
# ?-retry retrycount                  - numeric with ssh command
#           retry attempts before error
# ?-command sshclientcommandname      - string with ssh CLI
#           utility name (default ssh)
# ?-commandargs sshclientCLIarguments - string with ssh CLI
#           utility parameters
# ?-host sshhostname                  - string with ssh server hostname
# ?-port sshport                      - numeric with ssh server port
# ?-key keyfile                       - sprint with path to secret key file
# ?-username sshusername              - string with ssh username
# ?-password sshpassword              - string with ssh password
# ?--                                 - flag for stop parsing arguments
# command                             - string with command to execute
#           on remote server
#
# Side Effects:
# None.
#
# Results:
# list with command executed on remote SSH server output split by
# newline
# Error when ssh client namespace was not found
# Error when ssh command worked with error
# Error when password was specifient and Expect package could not inported
proc ::opsssh::ssh {args} {
	set args $args
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			{-sshId} -
			{-retry} -
			{-command} -
			{-commandargs} -
			{-host} -
			{-port} -
			{-key} -
			{-username} -
			{-password} {
				set [string trimleft $arg "-"] [lindex $args 1]
				set args [lrange $args 2 end]
			}
		}
	}
	# when sshId is set - get unconfigured values from namespace
	if [info exists sshId] {
		if [namespace exists ::opsssh::[set sshId]] {
			foreach variable_name {retry command commandargs host port key username password} {
				# get access to needed variables
				if ![info exists $variable_name] {
					variable ::opsssh::[set sshId]::[set variable_name]
				}
			}
		} else {
			# unknown sshId
			error "Unknown ssh client: $sshId"
		}
	}
	# make command list
	set ssh [split $commandargs]
	foreach {variable_name option_key} {username -l port -p key -i} {
		if [info exists $variable_name] {
			lappend ssh $option_key [set [set variable_name]]
		}
	}
	lappend ssh $host [lindex $args 0]
	variable null_password
	if {$password == $null_password} {
		# use key without password
		for {set i 0} {$i < $retry} {incr i} {
			if ![catch {eval [list exec $command] [lrange $ssh 0 end] [list 2>@ stdout] [lrange $args 1 end]} ssh_output] {
				break
			}
		}
		# check is command executed successful
		if {$i >= $retry} {
			# got error
			error "ssh output: $ssh_output"
		}
	} else {
		proc ssh_expect {command ssh password extra_args} {
			# use expact to enter password
			package require Expect
			# increase expect buffer size
			match_max -d 131072
			# disable expect echo
			log_user 0
			# run command
			eval [list spawn -noecho $command] [lrange $ssh 0 end] [lrange $extra_args 1 end]
			expect {
				-regexp "ssh.*Name or service not known.*" {
					error "ssh output: $expect_out(buffer)"
				}
				-regexp ".*Are.*.*yes.*no.*" {
					send "yes\n"
					exp_continue
					#look for the password prompt
				}
				"*?assword:*" {
					send $password
					send "\n"
					exp_continue
				}
				-regexp ".*ermission denied.*" {
					error "ssh output: $expect_out(buffer)"
				}
			}
			# remove 0x0D chars from expect output
			regsub -all -- {\x0d} $expect_out(buffer) {} ssh_output
			return $ssh_output
		}
		for {set i 0} {$i < $retry} {incr i} {
			if ![catch {ssh_expect $command $ssh $password $args} ssh_output] {
				break
			}
		}
		# check is command executed successful
		if {$i >= $retry} {
			# got error
			error $ssh_output
		}
	}
	return [split $ssh_output "\n"]
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
