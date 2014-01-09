#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# specify tcl prefer version \
TCL=tclsh
# prefer versions (mondiablo requires 8.4 and latter) 8.4 -> 8.6 -> 8.5 \
for v in 8.4 8.6 8.5; do type tclsh$v >/dev/null 2>&1 && TCL=tclsh$v; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

######################################################################
# MONOPS-1376 - diablo_counters.sh check services state and
# counters using Diablo web.
#
# This script checks service state and specified counters using Diablo
# web plugin (standard counters, status, node_status or ft_status pages)
# and return data in nagios format with perfdata or in cacti mode.
#
# Algorithm:
# 1) if node is not single
#  a) get nodes status page
#     if page not available - ERROR
#  b) parse status page and get active node link
#     if active node is not found - ERROR
# 2) get counters page from active node
#    if page not available - ERROR
# 3) find matched counters
# 4) if work in nagios mode - check counters values
# 5) print result
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
#           OK/WARNING/ERROR | counter1=perfdata
#           counter1=values
#           counter2=values
#           ...
#           counterN=values | counter2=perfdata
#           counter3=perfdata
#           ...
#           counterN=perfdata
#
#    Cacti:
#          counter1:value counter2:value ... counterN:value
#
# Maksym Tiurin (mtiurin@cisco.com) 04/11/2013
######################################################################

# add path to shared library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path "lib"]

# load module which provides exit codes and functions for format output
package require monoutput 0.2
# import CLI & config parser
package require opscfg

# default values
namespace eval script_parameters {
	variable verbose 0
	variable node_status_page "node_status"
	variable counters_page "counters"
	variable counters_thresholds {".* .*error.* dyn max 3 2 current_value"}
	variable node ""
	variable node_type "! standby"
	variable single 0
	variable cacti_output 0
	variable reduce_names 0
}

set USAGE "USAGE:
	[file tail $argv0] \[OPTIONS\]

Check service state and counters using Diablo web.

Options
	-h/--help         Show this help screen
	-v/--verbose      Verbose mode (default: [::opscfg::bool2text $::script_parameters::verbose])
	-n/--node         Checked node URL (with protocol and port)
	-T/--node-type    Needed node type (default: first non-standby node)
	-t/--thresholds   Counters thresholds for nagios specified using following format: \"component_regexp counter_regexp counter_type min/max/equal/nonequal error_value \[warning_value\] \[value_type\]\"
	                  where counter type one of dyn/st/ts and value_type one of current_value/current_rate/average_rate with default current_value and applicable for dyn counters only.
	                  For ts counter check values specified in seconds till now.
	                  Suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
	                  This option can be specified multiple times (default $::script_parameters::counters_thresholds)
	                  If one of specified thresholds is not find, this script returns ERROR.
	-S/--node-status  Path to node_status or ft_status page (default $::script_parameters::node_status_page)
	-C/--counters     Path to counters page (default $::script_parameters::counters_page)
	-s/--single       Single node without cluster node_status/ft_status page (default [::opscfg::bool2text $::script_parameters::single])
	-r/--reducenames  Reduce names of cacti field names and nagios perfdata names to 19 chars (default [::opscfg::bool2text $::script_parameters::reduce_names])
	-c/--cacti        Cacti type output (default [::opscfg::bool2text $::script_parameters::cacti_output])

Examples:

  [file tail $argv0] -n http://prod-avc-app1.vega.ironport.com:11080
 Open http://prod-avc-app1.vega.ironport.com:11080/node_status page, find active node, get /counters page from active node,
 check all error dyn counters current value and print result in Nagios format
 (when error counter current value >= 3 - ERROR, when error counter current value = 2 - WARNING, else OK).

  [file tail $argv0] -n http://prod-avc-app1.vega.ironport.com:11080 -t \"avc_daemon last_successful_update_published ts min 14d 7d\" -t \".* .*error.* dyn max 3 2 current_value\"
 Open http://prod-avc-app1.vega.ironport.com:11080/node_status page, find active node, get /counters page from active node,
 check all error dyn counters current value, check avc_daemon:last_successful_update_published:ts timestamp
 (when error counter current value >= 3 - ERROR, when error counter current value = 2 - WARNING,
  when avc_daemon:last_successful_update_published older than 14 days - ERROR, when avc_daemon:last_successful_update_published older than 7 days - WARNING else OK)
 and print result in Nagios format

  [file tail $argv0] --node http://stage-catbayes-app1.vega.ironport.com:31080 --single --counters Counters
 Get counters from http://stage-catbayes-app1.vega.ironport.com:31080/Counters page,
 check all error dyn counters current value and print result in Nagios format
 (when error counter current value >= 3 - ERROR, when error counter current value = 2 - WARNING, else OK).

  [file tail $argv0] --node http://stage-catbayes-app1.vega.ironport.com:31080 --single --counters Counters --cacti
 Get counters from http://stage-catbayes-app1.vega.ironport.com:31080/Counters page,
 print all error dyn counters in Cacti format.
"

# parse CLI options
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit 0
}
if [::opscfg::getopt argv [list "-v" "--verbose"]] {
	set ::script_parameters::verbose 1
}
if [::opscfg::getopt argv [list "-s" "--single"]] {
	set ::script_parameters::single 1
}
::opscfg::getopt argv [list "-S" "--node-status"] ::script_parameters::node_status_page
::opscfg::getopt argv [list "-C" "--counters"] ::script_parameters::counters_page
::opscfg::getopt argv [list "-T" "--node-type"] ::script_parameters::node_type
if {[::opscfg::getopt argv [list "-c" "--cacti"]]} {
	set ::script_parameters::cacti_output 1
}
if [::opscfg::getopt argv [list "-r" "--reducenames"]] {
	set ::script_parameters::reduce_names 1
}
::opscfg::getopt argv [list "-n" "--node"] ::script_parameters::node
while {[::opscfg::getopt argv [list "-t" "--thresholds"] threshold]} {
	set threshold_list [split $threshold]
	if {[llength $threshold_list] < 5} {
		puts stderr "Invalid threshold specification \"$threshold\""
		puts $USAGE
		exit $EXIT_UNKNOWN
	}
	# check counter_type
	switch -exact -- [lindex $threshold_list 2] {
		"st" {
			set counter_type "st"
		}
		"ts" {
			set counter_type "ts"
		}
		default {
			set counter_type "dyn"
		}
	}
	switch -exact -- [lindex $threshold_list 3] {
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
	set counter_error [lindex $threshold_list 4]
	if {[llength $threshold_list] >= 6} {
		set counter_warning [lindex $threshold_list 5]
	} else {
		set counter_warning $counter_error
	}
	switch -exact -- $counter_type {
		"ts" {
			# expand and calculate value
			set counter_error [expr [clock seconds] - [::opscfg::expandtime $counter_error]]
			set counter_warning [expr [clock seconds] - [::opscfg::expandtime $counter_warning]]
			# ts counters have only current value
			set value_type "current value"
		}
		"st" {
			# st counters have only current value
			set value_type "current value"
		}
		default {
			if {[llength $threshold_list] == 7} {
				switch -exact -- [lindex $threshold_list 6] {
					"current_rate" {
						set value_type "current rate"
					}
					"average_rate" {
						set value_type "average rate"
					}
					default {
						set value_type "current value"
					}
				}
			} else {
				set value_type "current value"
			}
		}
	}
	# add threshold to list
	lappend new_counters_thresholds [list [lindex $threshold_list 0] [lindex $threshold_list 1] $counter_type $check_type $counter_error $counter_warning $value_type]
}
if [info exists new_counters_thresholds] {
	set ::script_parameters::counters_thresholds $new_counters_thresholds
} else {
	# replace "current_value" to "current value"
	set ::script_parameters::counters_thresholds [list [lreplace [lindex $::script_parameters::counters_thresholds 0] end end "current value"]]
}
# check that all params are present
foreach v [info vars ::script_parameters::*] {
	if {[set [set v]] == ""} {
		puts stderr "parameter [namespace tail $v] value should be set"
		exit $EXIT_UNKNOWN
	}
}
if ![regexp {^http://.*:\d+/?} $::script_parameters::node] {
	puts stderr "Bad node address: $::script_parameters::node"
	puts stderr "It should be http://hostname:port"
	exit $EXIT_UNKNOWN
}
if {$::script_parameters::verbose} {
	# print script parameter variables with value
	puts stderr "Script parameters:"
	foreach v [info vars ::script_parameters::*] {
		puts stderr "\t[namespace tail $v] = [set [set v]]"
	}
}
########## main part
package require http
package require mondiablo 0.2
http::config -useragent "Monitoring"
if !$::script_parameters::single {
	# get node status page
	if {$::script_parameters::verbose} {
		puts stderr "Getting page $::script_parameters::node/$::script_parameters::node_status_page"
	}
	if [catch {http::geturl "$::script_parameters::node/$::script_parameters::node_status_page"} status_token] {
		# unable to connect
		if {$::script_parameters::verbose} {
			puts stderr "unable to connect to $::script_parameters::node/$::script_parameters::node_status_page"
			global errorCode
			puts stderr "exit code $errorCode"
			puts stderr "output: $status_token"
		}
		if {!$::script_parameters::cacti_output} {
			::monoutput::nagiosoutput "ERROR - Node status page is not available"
		}
		exit $EXIT_ERROR
	}
	# check status
	if ![regexp {^HTTP.*200\s+OK$} [http::code $status_token]] {
		# error when getting node status
		if {$::script_parameters::verbose} {
			puts stderr "page return code: \"[http::code $status_token]\""
		}
		if {!$::script_parameters::cacti_output} {
			::monoutput::nagiosoutput "ERROR - Node status page is not available"
		}
		exit $EXIT_ERROR
	}
	# get nodes statuses
	array set nodes_status_array [::mondiablo::parseftstatus [http::data $status_token]]
	if {[array names nodes_status_array] == {}} {
		# we did not get node status
		if {!$::script_parameters::cacti_output} {
			::monoutput::nagiosoutput "ERROR - Node status page is not a node status page"
		}
		exit $EXIT_ERROR
	}
	# clean token
	http::cleanup $status_token
	if $::script_parameters::verbose {
		puts stderr "got nodes status array:"
		puts stderr[array get nodes_status_array]
	}
	# find needed active node
	foreach node [array names nodes_status_array] {
		array unset node_status_array
		array set node_status_array $nodes_status_array($node)
		if {$::script_parameters::node_type == "! standby"} {
			# find first active node
			if {$node_status_array(node_state) != "standby"} {
				# active node was found
				set active_node "http://$node_status_array(link)"
				break
			}
		} else {
			# find specified node
			if {$node_status_array(node_state) == $::script_parameters::node_type} {
				# node was found
				set active_node "http://$node_status_array(link)"
				break
			}
		}
	}
	if ![info exists active_node] {
		# active node was not found
		if {!$::script_parameters::cacti_output} {
			::monoutput::nagiosoutput "ERROR - Unable to find active node"
		}
		exit $EXIT_ERROR
	}
} else {
	set active_node $::script_parameters::node
}
# get active node counters
if {$::script_parameters::verbose} {
	puts stderr "Getting counters page $active_node/$::script_parameters::counters_page"
}
if [catch {http::geturl "$active_node/$::script_parameters::counters_page"} status_token] {
	# unable to connect
	if {$::script_parameters::verbose} {
		puts stderr "unable to connect to $active_node/$::script_parameters::counters_page"
		global errorCode
		puts stderr "exit code $errorCode"
		puts stderr "output: $status_token"
	}
	if {!$::script_parameters::cacti_output} {
		::monoutput::nagiosoutput "ERROR - Node status page is not available"
	}
	exit $EXIT_ERROR
}
# check status
if ![regexp {^HTTP.*200\s+OK$} [http::code $status_token]] {
	# error when getting node status
	if {$::script_parameters::verbose} {
		puts stderr "page return code: \"[http::code $status_token]\""
	}
	if {!$::script_parameters::cacti_output} {
		::monoutput::nagiosoutput "ERROR - Node counters page is not available"
	}
	exit $EXIT_ERROR
}
# parse counters
array set counters_array [::mondiablo::parsecounters [http::data $status_token]]
if {[array names counters_array] == {}} {
	# we did not get counters
	if {!$::script_parameters::cacti_output} {
		::monoutput::nagiosoutput "ERROR - Node counters page is not a node counters page"
	}
	exit $EXIT_ERROR
}
# clean token
http::cleanup $status_token
if $::script_parameters::verbose {
	puts stderr "got node counters array:"
	puts stderr[array get counters_array]
}
# format result array
array unset result_array
set exit_code $EXIT_OK
set exit_message "OK"
foreach threshold $::script_parameters::counters_thresholds {
	# in threshold list item 0 - component regexp, 1 - counter regexp,
	# 2 - counter type
	# get matched components
	set matched_components [array names counters_array -regexp [lindex $threshold 0]]
	if {$matched_components == {}} {
		set exit_code $EXIT_ERROR
		set exit_message "Threshold \"$threshold\" did not find in the counters components"
	}
	foreach component $matched_components {
		array unset component_counters_array
		array set component_counters_array $counters_array($component)
		# get matched counters
		set matched_counters [array names component_counters_array -regexp [lindex $threshold 1]]
		if {$matched_counters == {}} {
			set exit_code $EXIT_ERROR
			set exit_message "Threshold \"$threshold\" did not find in the counters"
			continue
		}
		set matched_counter 0
		foreach counter $matched_counters {
			array unset counter_array
			array set counter_array $component_counters_array($counter)
			set matched_counter 0
			if {[lindex $threshold 2] == $counter_array(type)} {
				# needed counter
				set matched_counter 1
				# add needed value to array
				set result_array_key "$component:$counter:[lindex $threshold 6]"
				if {[array names result_array -exact $result_array_key] == {}} {
					if {$counter_array(type) == "ts"} {
						set result_array($result_array_key) [list $counter_array([lindex $threshold 6]) "$result_array_key = [clock format $counter_array([lindex $threshold 6]) -format {%Y-%m-%dT%H:%M:%S}]"]
					} else {
						set result_array($result_array_key) [list $counter_array([lindex $threshold 6]) "$result_array_key = $counter_array([lindex $threshold 6])"]
					}
				}
				if !$::script_parameters::cacti_output {
					# check counter value
					switch -exact -- [lindex $threshold 3] {
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
					if {[expr [lindex $result_array($result_array_key) 0] $comparison [lindex $threshold 4]]} {
						# error value
						if {$exit_code != $EXIT_ERROR} {
							set exit_code $EXIT_ERROR
							if {$counter_array(type) == "ts"} {
								# convert unix time to text
								set exit_message "ERROR - $result_array_key equal to [clock format [lindex $result_array($result_array_key) 0] -format {%Y-%m-%dT%H:%M:%S}] but [lindex $threshold 3] is [clock format [lindex $threshold 4] -format {%Y-%m-%dT%H:%M:%S}]"
							} else {
								set exit_message "ERROR - $result_array_key equal to [lindex $result_array($result_array_key) 0] but [lindex $threshold 3] is [lindex $threshold 4]"
							}
						}
					} elseif {[expr [lindex $result_array($component:$counter:[lindex $threshold 6]) 0] $comparison [lindex $threshold 5]]} {
						# warning value
						if {($exit_code != $EXIT_ERROR) && ($exit_code != $EXIT_WARNING)} {
							set exit_code $EXIT_WARNING
							if {$counter_array(type) == "ts"} {
								# convert unix time to text
								set exit_message "WARNING - $result_array_key equal to [clock format [lindex $result_array($result_array_key) 0] -format {%Y-%m-%dT%H:%M:%S}] but [lindex $threshold 3] is [clock format [lindex $threshold 5] -format {%Y-%m-%dT%H:%M:%S}]"
							} else {
								set exit_message "WARNING - $result_array_key equal to [lindex $result_array($result_array_key) 0] but [lindex $threshold 3] is [lindex $threshold 5]"
							}
						}
					}
				}
			}
		}
		if !$matched_counter {
			set exit_code $EXIT_ERROR
			set exit_message "Threshold \"$threshold\" did not find in the counters (type mismatch)"
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
