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
# MONOPS-1415 - diablo_web_status.sh check services state using Diablo
# web.
#
# This script checks service state page and return message with exit
# code for nagios.
#
# Algorithm:
# 1) get status page
#     if page not available - ERROR
# 2) parse status page
#     if status page is empty - ERROR
# 3) check status thresholds
#     if matched status entries not found - ERROR
# 4) check plugins thresholds
#     if matched plugins entries not found - ERROR
# 5) print result
#
# Return codes and their meaning:
#    Nagios:
#           0 (ok)
#           2 (critical) - when specified hosts not available or
#                          counters went beyond the specified bounds.
#           3 (unknown) - when specified bad CLI options.
#
# Output:
#    Nagios:
#           OK/ERROR message
#
# Maksym Tiurin (mtiurin@cisco.com) 05/21/2013
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
	variable node_status_page "status"
	variable plugins_thresholds {".* .* .*"}
	variable status_thresholds {".* .*"}
	variable node ""
}

set USAGE "USAGE:
	[file tail $argv0] \[OPTIONS\]

Check service status using Diablo web.

Options
	-h/--help                Show this help screen
	-v/--verbose             Verbose mode (default: [::opscfg::bool2text $::script_parameters::verbose])
	-n/--node                Checked node URL (with protocol and port)
	-s/--status              Path to status page (default: $::script_parameters::node_status_page)
	-S/--status-thresholds   Status thresholds specified using following format: \"key_regexp value_regexp\"
	                         Passed when matched key with value was found.
	                         This option can be specified multiple times (default $::script_parameters::status_thresholds)
	-P/--plugins-thresholds  Plugins thresholds specified using following format: \"plugin_regexp key_regexp value_regexp\"
	                         This option can be specified multiple times (default $::script_parameters::plugins_thresholds)
	                         If one of specified thresholds is not find, this script returns ERROR.

Examples:

  [file tail $argv0] --node http://prod-avc-app1.vega.ironport.com:11080 --status-thresholds \"user avc\" --plugins-thresholds \"zkft .*status CONNECTED_STATE\"
 Get status page from http://prod-avc-app1.vega.ironport.com:11080/status,
 check that application runs with avc privileges and zkft plugin status is connected
"

# parse CLI options
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit 0
}
if [::opscfg::getopt argv [list "-v" "--verbose"]] {
	set ::script_parameters::verbose 1
}
::opscfg::getopt argv [list "-n" "--node"] ::script_parameters::node
::opscfg::getopt argv [list "-s" "--status"] ::script_parameters::node_status_page
while {[::opscfg::getopt argv [list "-S" "--status-thresholds"] threshold]} {
	set threshold_list [split $threshold]
	if {[llength $threshold_list] < 2} {
		puts stderr "Invalid status threshold specification \"$threshold\""
		puts $USAGE
		exit $EXIT_UNKNOWN
	}
	# add threshold to list
	lappend new_counters_thresholds [list [lindex $threshold_list 0] [lindex $threshold_list 1]]
}
if [info exists new_counters_thresholds] {
	set ::script_parameters::status_thresholds $new_counters_thresholds
	unset new_counters_thresholds
}
while {[::opscfg::getopt argv [list "-P" "--plugins-thresholds"] threshold]} {
	set threshold_list [split $threshold]
	if {[llength $threshold_list] < 3} {
		puts stderr "Invalid plugins threshold specification \"$threshold\""
		puts $USAGE
		exit $EXIT_UNKNOWN
	}
	# add threshold to list
	lappend new_counters_thresholds [list [lindex $threshold_list 0] [lindex $threshold_list 1] [lindex $threshold_list 2]]
}
if [info exists new_counters_thresholds] {
	set ::script_parameters::plugins_thresholds $new_counters_thresholds
	unset new_counters_thresholds
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
	::monoutput::nagiosoutput "ERROR - Node status page is not available"
	exit $EXIT_ERROR
}
# check status
if ![regexp {^HTTP.*200\s+OK$} [http::code $status_token]] {
	# error when getting node status
	if {$::script_parameters::verbose} {
		puts stderr "page return code: \"[http::code $status_token]\""
	}
	::monoutput::nagiosoutput "ERROR - Node status page is not available"
	exit $EXIT_ERROR
}
# get nodes statuses
array set node_status_array [::mondiablo::parsestatus [http::data $status_token]]
if {[array names node_status_array] == {}} {
	# we did not get node status
	::monoutput::nagiosoutput "ERROR - Node status page is not a node status page or empty"
	exit $EXIT_ERROR
}
# clean token
http::cleanup $status_token
if $::script_parameters::verbose {
	puts stderr "got nodes status array:"
	puts stderr[array get node_status_array]
}
# check status thresholds
set exit_code $EXIT_OK
set exit_message "OK"
foreach threshold $::script_parameters::status_thresholds {
	# in threshold list item 0 - key regexp, 1 - value
	set matched_components [array names node_status_array -regexp [lindex $threshold 0]]
	if {$matched_components == {}} {
		set exit_code $EXIT_ERROR
		set exit_message "Status threshold \"$threshold\" did not find in the status page"
	}
	set matched_counter 0
	foreach component $matched_components {
		if [regexp [lindex $threshold 1] $node_status_array($component)] {
			set matched_counter 1
			break
		}
	}
	if !$matched_counter {
		::monoutput::nagiosoutput "ERROR - Status threshold \"$threshold\" did not match in the status page"
		exit $EXIT_ERROR
	}
}
if {[array names node_status_array -exact "plugins"] == {}} {
	::monoutput::nagiosoutput "ERROR - Status page do not contain plugins JSON"
	exit $EXIT_ERROR
}
array set plugins_array $node_status_array(plugins)
foreach threshold $::script_parameters::plugins_thresholds {
	# in threshold list item 0 - plugin regexp, 1 - key regexp, 2 - value
	set matched_components [array names plugins_array -regexp [lindex $threshold 0]]
	if {$matched_components == {}} {
		set exit_code $EXIT_ERROR
		set exit_message "Plugin \"[lindex $threshold 0]\" did not find in the status page"
	}
	foreach component $matched_components {
		array unset plugin_array
		array set plugin_array $plugins_array($component)
		set matched_keys [array names plugin_array -regexp [lindex $threshold 1]]
		set matched_counter 0
		foreach key $matched_keys {
			if [regexp [lindex $threshold 2] $plugin_array($key)] {
				set matched_counter 1
				break
			}
		}
		if !$matched_counter {
			::monoutput::nagiosoutput "ERROR - Plugins did not match threshold \"$threshold\""
			exit $EXIT_ERROR
		}
	}
}
::monoutput::nagiosoutput $exit_message
exit $exit_code

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
