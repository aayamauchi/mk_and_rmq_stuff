lappend auto_path [file dirname [info script]]

namespace eval ::opsdb {
	namespace export opsdb
	variable version 0.2
	variable mysql_idx 0
}

package provide opsdb $::opsdb::version
# ::opsdb::openmysql -- create namespace with mysql client parameters
#
# Create new namespace for mysql client and fill specified values to it.
#
# Arguments:
# ?-retry retrycount                    - numeric with mysql command
#           retry attempts before error
# ?-command mysqlclientcommandname      - string with mysql CLI
#           utility name (default mysql)
# ?-commandargs mysqlclientCLIarguments - string with mysql CLI
#           utility parameters
# ?-host mysqlhostname                  - string with mysql server hostname
# ?-port mysqlport                      - numeric with mysql server port
# ?-username mysqlusername              - string with mysql username
# ?-password mysqlpassword              - string with mysql password
# ?-database mysqldatabasename          - string with mysql database name
# ?--                                   - flag for stop parsing arguments
#
# Side Effects:
# Create new namespace opsdb::mysqlN with mysql client settings
# variables.
#
# Results:
# string with new mysql client namespace name
proc ::opsdb::openmysql {args} {
	variable mysql_idx
	incr mysql_idx
	namespace eval ::opsdb::mysql[set mysql_idx] {
		variable retry 1
		variable command "mysql"
		variable commandargs "-s"
		variable host "localhost"
		variable port 3306
		variable username ""
		variable password ""
		variable database ""
	} 
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
			{-username} -
			{-password} -
			{-database} {
				set ::opsdb::mysql[set mysql_idx]::[string trimleft $arg "-"] [lindex $args 1]
				set args [lrange $args 2 end]
			}
		}
	}
	return "mysql[set mysql_idx]"
}
# ::opsdb::closemysql -- delete namespace with mysql client parameters
#
# Delete specified namespace with mysql parameters
#
# Arguments:
# mysqlId   - string with mysql client namespace name
#
# Side Effects:
# Delete appropriate mysql namespace opsdb::mysqlN with mysql client
# settings variables.
#
# Results:
# 0 when function is worked successfully
# -1 when log namespace does not exists
proc ::opsdb::closemysql {mysqlId} {
	if [namespace exists ::opsdb::[set mysqlId]] {
		namespace delete ::opsdb::[set mysqlId]
		return 0
	} else {
		return 1
	}
}
# ::opsdb::mysql -- run queue on MySQL server
#
# Run queue on specified MySQL server and return formated result.
# When mysql client namespace is specified this function get
# parameters for mysql client from specified namespace and other
# optional arguments overrides appropriate values.
# When mysql client namespace is not specified you must define all
# other optional arguments.
#
# Arguments:
# ?-mysqlId                             - string with mysql client
#           namespace name
# ?-retry retrycount                    - numeric with mysql command
#           retry attempts before error
# ?-command mysqlclientcommandname      - string with mysql CLI
#           utility name (default mysql)
# ?-commandargs mysqlclientCLIarguments - string with mysql CLI
#           utility parameters
# ?-host mysqlhostname                  - string with mysql server hostname
# ?-port mysqlport                      - numeric with mysql server port
# ?-username mysqlusername              - string with mysql username
# ?-password mysqlpassword              - string with mysql password
# ?-database mysqldatabasename          - string with mysql database name
# ?--                                   - flag for stop parsing arguments
# sqlqueue                              - string with SQL queue to execute
#
# Side Effects:
# None.
#
# Results:
# list with arrays as list which contains data returned from MySQL
# server. Format of this structure is:
# { {fieldname1 value2 fieldname2 value2 ...}
#   {fieldname1 value2 fieldname2 value2 ...}
#   ...
# }
# where list items is an array as list (array get result) with row content.
# Error when mysql client namespace was not found
# Error when mysql command worked with error
proc ::opsdb::mysql {args} {
	set args $args
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			{-mysqlId} -
			{-retry} -
			{-command} -
			{-commandargs} -
			{-host} -
			{-port} -
			{-username} -
			{-password} -
			{-database} {
				set [string trimleft $arg "-"] [lindex $args 1]
				set args [lrange $args 2 end]
			}
		}
	}
	# when mysqlId is set - get unconfigured values from namespace
	if [info exists mysqlId] {
		if [namespace exists ::opsdb::[set mysqlId]] {
			foreach variable_name {retry command commandargs host port username password database} {
				# get access to needed variables
				if ![info exists $variable_name] {
					variable ::opsdb::[set mysqlId]::[set variable_name]
				}
			}
		} else {
			# unknown mysqlId
			error "Unknown mysql client: $mysqlId"
		}
	}
	# drop command separator from SQL queue if needed and add "\G"
	set sql "[string trimright [lindex $args 0] {; }]\\G"
	# make command list
	set mysql [concat [split $commandargs] [list "-h$host" "-P" $port "-u$username" "-p$password" "-e" $sql $database]]
	for {set i 0} {$i < $retry} {incr i} {
		if ![catch {eval [list exec $command] [lrange $mysql 0 end] [list 2>@ stdout]} mysql_output] {
			break
		}
	}
	# check is command executed successful
	if {$i >= $retry} {
		# got error
		error $mysql_output
	}
	set result_list {}
	array unset record_array
	set current_field_name ""
	foreach line [split $mysql_output "\n"] {
		if [regexp -expanded {^\*+\s+\d+\.\s+row\s+\*+$} $line] {
			# new DB record
			if {[array names record_array] != {}} {
				# add array content to result list
				lappend result_list [array get record_array]
			}
			array unset record_array
			set current_field_name ""
		} elseif [regexp -expanded {^\s*(\w.*?):\s+(.*)$} $line match name value] {
			# DB record field
			set record_array($name) $value
			set current_field_name $name
		} elseif {$current_field_name != ""} {
			# multiline value - add it to field value
			set record_array($current_field_name) "$record_array($current_field_name)\n$line"
		}
		# else - skip line
	}
	# process last record
	if {[array names record_array] != {}} {
		# add array content to result list
		lappend result_list [array get record_array]
	}
	return $result_list
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
