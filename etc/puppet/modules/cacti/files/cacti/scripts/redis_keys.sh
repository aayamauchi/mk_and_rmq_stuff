#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# define tcl prefer version \
TCL=tclsh
# prefer versions 8.4 -> 8.6 -> 8.5 \
for v in 8.4 8.6 8.5; do type tclsh$v >/dev/null 2>&1 && TCL=tclsh$v; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

######################################################################
# MONOPS-1981 - redis_keys.sh check keys count in Redis.
#
# This script checks count of specified keys in the Redis database
# and return data in nagios format with perfdata or in cacti mode.
#
# Algorithm:
# 1) run redis queue
# 2) calculate length of returned list
# 3) if work in nagios mode - check list length
# 4) print result
#
# Return codes and their meaning:
#    Nagios:
#           0 (ok)
#           2 (critical) - when specified hosts not available or
#                          counters went beyond the specified bounds.
#           3 (unknown) - when specified bad CLI options.
#
#    Cacti:
#           0 (ok)
#           2 (critical) - when specified hosts not available.
#           3 (unknown) - when specified bad CLI options.
#
# Output:
#    Nagios:
#           OK/WARNING/ERROR | key1=perfdata
#           key1=values
#           key2=values
#           ...
#           keyN=values | key2=perfdata
#           key3=perfdata
#           ...
#           keyN=perfdata
#
#    Cacti:
#          key1:value key2:value ... keyN:value
#
# Maksym Tiurin (mtiurin@cisco.com) 10/11/2013
######################################################################

# add path to shared library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path "lib"]

# load module which provides exit codes and functions for format output
package require monoutput 0.2
# import CLI & config parser
package require opscfg 1.1

# default values
namespace eval script_parameters {
	variable verbose 0
	variable database 0
	variable database_host "localhost"
	variable database_port "6379"
	variable database_password ""
	variable retry_count 2
	variable queries {}
	variable counters_thresholds {".* max 1000 900"}
	variable cacti_output 0
	variable reduce_names 0
}

set USAGE "USAGE:
	[file tail $argv0] \[OPTIONS\]

Check keys count in Redis.

Options
	-h/--help         Show this help screen
	-v/--verbose      Verbose mode (default: [::opscfg::bool2text $::script_parameters::verbose])
	-d/--db           Redis database number (default: $::script_parameters::database)
	-H/--host         Redis hostname to connect (default: $::script_parameters::database_host)
	-P/--port         Redis port to connect (default: $::script_parameters::database_port)
	-p/--password     Redis password to connect (default: $::script_parameters::database_password)
	-R/--retry-count  Redis connection attempts (default: $::script_parameters::retry_count)
	-q/--query        Key match string to find
	                  This option can be specified multiple times
	-t/--thresholds   Count thresholds for nagios specified using following format: \"key_regexp min/max/equal/notequal error_value \[warning_value\]\"
	                  This option can be specified multiple times (default $::script_parameters::counters_thresholds)
	-r/--reducenames  Reduce names of cacti field names and nagios perfdata names to 19 chars (default [::opscfg::bool2text $::script_parameters::reduce_names])
	-c/--cacti        Cacti type output (default [::opscfg::bool2text $::script_parameters::cacti_output])

Examples:

  [file tail $argv0] -H ops-mon-nagios1.vega.ironport.com -p redis_password \\
  -q \"jiranotif:*\" \\
  -q \"jiraproc:*\" \\
  -t \"jiranotif.* max 800 1000\" \\
  -t \"jiraproc.* max 150 200\"
 Request specified keys from default Redis database, calculate keys count, check it and print result in Nagios format
 (when jira notifications count >= 1000 - ERROR, when jira notifications count >= 800 - WARNING
  when jira-convert locks count >= 200 - ERROR, when jira-convert locks count >= 150 - WARNING, else OK)

  [file tail $argv0] -H ops-mon-nagios1.vega.ironport.com -p redis_password \\
  -q \"jiranotif:*\" \\
  -q \"jiraproc:*\" \\
  -t \"jiranotif.* max 800 1000\" \\
  -t \"jiraproc.* max 150 200\"
 The same but return keys count in Cacti format without values check.
"

# parse CLI options
# print USAGE if run without CLI args
if {$argc == 0} {
	puts $USAGE
	exit $EXIT_UNKNOWN
}
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit $EXIT_UNKNOWN
}
# switches
::opscfg::getswitchopt argv [list "-v" "--verbose"] ::script_parameters::verbose
::opscfg::getswitchopt argv [list "-c" "--cacti"] ::script_parameters::cacti_output
::opscfg::getswitchopt argv [list "-r" "--reducenames"] ::script_parameters::reduce_names
# parameters
::opscfg::getopt argv [list "-d" "--db"] ::script_parameters::database
::opscfg::getopt argv [list "-H" "--host"] ::script_parameters::database_host
::opscfg::getopt argv [list "-P" "--port"] ::script_parameters::database_port
::opscfg::getopt argv [list "-p" "--password"] ::script_parameters::database_password
::opscfg::getopt argv [list "-R" "--retry-count"] ::script_parameters::retry_count
while {[::opscfg::getopt argv [list "-t" "--thresholds"] threshold]} {
	# threshold specification: "key_regexp min/max/equal/nonequal error_value \[warning_value\]"
	set threshold_list [split $threshold]
	if {[llength $threshold_list] < 3} {
		puts stderr "Invalid threshold specification \"$threshold\""
		puts $USAGE
		exit $EXIT_UNKNOWN
	}
	switch -exact -- [lindex $threshold_list 1] {
		"min" {
			set check_type "min"
		}
		"equal" {
			set check_type "equal"
		}
		"notequal" {
			set check_type "notequal"
		}
		default {
			set check_type "max"
		}
	}
	set counter_error [lindex $threshold_list 2]
	if {[llength $threshold_list] >= 4} {
		set counter_warning [lindex $threshold_list 3]
	} else {
		set counter_warning $counter_error
	}
	# add threshold to list
	lappend new_counters_thresholds [list [lindex $threshold_list 0] $check_type $counter_error $counter_warning]
}
if [info exists new_counters_thresholds] {
	set ::script_parameters::counters_thresholds $new_counters_thresholds
}
while {[::opscfg::getopt argv [list "-q" "--query"] query]} {
	# add queue to list
	lappend ::script_parameters::queries $query
}
# check that all params are present
foreach v [info vars ::script_parameters::*] {
	if {([set [set v]] == "") && ([set v] != "::script_parameters::database_password")} {
		puts stderr "parameter [namespace tail $v] value should be set"
		exit $EXIT_UNKNOWN
	}
}
if {$::script_parameters::verbose} {
	# print script parameter variables with value
	puts stderr "Script parameters:"
	foreach v [info vars ::script_parameters::*] {
		puts stderr "\t[namespace tail $v] = [set [set v]]"
	}
}
########## main part
package require opsredis
# create redis client
if [catch {redis $::script_parameters::database_host $::script_parameters::database_port} redisId] {
	if {!$::script_parameters::cacti_output} {
		::monoutput::nagiosoutput "ERROR - Unable to connect"
	}
	if {$::script_parameters::verbose} {
		global errorInfo
		puts stderr "Tcl traceback: $errorInfo"
	}
	exit $EXIT_ERROR
}
if {$::script_parameters::database_password != ""} {
	# try to auth
	if {[$redisId AUTH $::script_parameters::database_password] != "OK"} {
		if {!$::script_parameters::cacti_output} {
			::monoutput::nagiosoutput "ERROR - Unable to auth"
		}
		$redisId "close"
		exit $EXIT_ERROR
	}
}
# database choose
$redisId SELECT $::script_parameters::database
# format result array
array unset keys_count_array
# run requests
foreach query $::script_parameters::queries {
	# run request
	if $::script_parameters::verbose {
		puts stderr "Request key: \"$query\""
	}
	if [catch {$redisId KEYS $query} keys_list] {
		# got error
		if $::script_parameters::verbose {
			global errorInfo
			puts stderr "Query execution error: $errorInfo"
		}
		if {!$::script_parameters::cacti_output} {
			::monoutput::nagiosoutput "ERROR - Redis query execution failed"
		}
		exit $EXIT_ERROR
	} else {
		# add result to array
		set keys_count_array($query) [llength $keys_list]
	}
}
# close client
$redisId "close"
if $::script_parameters::verbose {
	puts stderr "Got following keys count from Redis:"
	puts stderr [array get keys_count_array]
}
set exit_code $EXIT_OK
set exit_message "OK"
# format result array
array unset result_array
foreach threshold $::script_parameters::counters_thresholds {
	# in threshold list item 0 - keys regexp,
	# 1 - comparison 
	# 2 - error threshold
	# 3 - warning threshold
	# get matched counters
	foreach key [array names keys_count_array -regexp [lindex $threshold 0]] {
		# add needed value to array
		set result_array($key) [list $keys_count_array($key) "$key count = $keys_count_array($key)"]
		if !$::script_parameters::cacti_output {
			# check counter value
			switch -exact -- [lindex $threshold 1] {
				"min" {
					set comparison "<="
				}
				"equal" {
					set comparison "=="
				}
				"notequal" {
					set comparison "!="
				}
				default {
					set comparison ">="
				}
			}
			if {[expr [lindex $result_array($key) 0] $comparison [lindex $threshold 2]]} {
				# error value
				if {$exit_code != $EXIT_ERROR} {
					set exit_code $EXIT_ERROR
					set exit_message "ERROR - $key count equal to [lindex $result_array($key) 0] but [lindex $threshold 1] is [lindex $threshold 2]"
				}
			} elseif {[expr [lindex $result_array($key) 0] $comparison [lindex $threshold 3]]} {
				# warning value
				if {($exit_code != $EXIT_ERROR) && ($exit_code != $EXIT_WARNING)} {
					set exit_code $EXIT_WARNING
					set exit_message "WARNING - $key count equal to [lindex $result_array($key) 0] but [lindex $threshold 1] is [lindex $threshold 3]"
				}
			}
		}
	}
}
# print result
if $::script_parameters::cacti_output {
	if $::script_parameters::reduce_names {
		::monoutput::cactioutput -reducenames [array get result_array]
	} else {
		::monoutput::cactioutput [array get result_array]
	}
	exit $EXIT_OK
} else {
	if $::script_parameters::reduce_names {
		::monoutput::nagiosoutput -reducenames -data [array get result_array] $exit_message
	} else {
		::monoutput::nagiosoutput -data [array get result_array] $exit_message
	}
	exit $exit_code
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
