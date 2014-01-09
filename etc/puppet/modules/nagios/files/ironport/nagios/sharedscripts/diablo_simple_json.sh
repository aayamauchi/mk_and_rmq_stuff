#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# define tcl prefer version \
TCL=tclsh
# prefer versions (mondiablo requires 8.4 and latter) 8.4 -> 8.6 -> 8.5 \
for v in 8.4 8.6 8.5; do type tclsh$v >/dev/null 2>&1 && TCL=tclsh$v; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

######################################################################
# MONOPS-1376 - diablo_web_counters.sh check services counters using
# Diablo web when counters are provided as simple one level JSON.
#
# This script checks specified counters using Diablo web plugin  when
# counters are provided by simple one level JSON and return data in
# nagios format with perfdata or in cacti mode.
#
# Return codes and their meaning:
#    Nagios:
#           0 (ok)
#           1 (warning)  - when counters went beyond the specified bounds.
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
# Maksym Tiurin (mtiurin@cisco.com) 04/22/2013
#
# Added tsmax threshold to handle timestamp counters
# https://jira.sco.cisco.com/browse/MONOPS-1570
# Alert if timestamp is older then warning/critical threshold
# WARNING: do not use timestamp counter, tsmax threshold in cacti mode
# 
# Bogdan Berezovyi (bberezov@cisco.com) 10/24/2013
# 
######################################################################

# add path to shared library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path "lib"]

# load module which provides exit codes and functions for format output
package require monoutput
# import CLI & config parser
package require opscfg

# default values
namespace eval script_parameters {
	variable verbose 0
	variable counters_thresholds {".*error.* max 3 2"}
	variable node ""
	variable counters_page "counters"
	variable cacti_output 0
	variable reduce_names 0
}

set USAGE "USAGE:
	[file tail $argv0] \[OPTIONS\]

Check service counters in JSON format using Diablo web.

Options
	-h/--help         Show this help screen
	-v/--verbose      Verbose mode (default: [::opscfg::bool2text $::script_parameters::verbose])
	-n/--node         Checked node URL (with protocol and port)
	-t/--thresholds   Counters thresholds for nagios specified using following format: \"counter_regexp min/max/tsmax/equal/notequal error_value \[warning_value\]\"
	                  This option can be specified multiple times (default $::script_parameters::counters_thresholds)
	--counters        Path to counters page (default $::script_parameters::counters_page)
	--reducenames     Reduce names of cacti field names and nagios perfdata names to 19 chars (default [::opscfg::bool2text $::script_parameters::reduce_names])
	-c/--cacti        Cacti type output (default [::opscfg::bool2text $::script_parameters::cacti_output])

"

# parse CLI options
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit 0
}
if [::opscfg::getopt argv [list "-v" "--verbose"]] {
	set ::script_parameters::verbose 1
}
if [::opscfg::getopt argv "--reducenames"] {
	set ::script_parameters::reduce_names 1
}
::opscfg::getopt argv "--counters" ::script_parameters::counters_page
if {[::opscfg::getopt argv [list "-c" "--cacti"]]} {
	set ::script_parameters::cacti_output 1
}
::opscfg::getopt argv [list "-n" "--node"] ::script_parameters::node
while {[::opscfg::getopt argv [list "-t" "--thresholds"] threshold]} {
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
		"tsmax" {
			set check_type "tsmax"
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
http::config -useragent "Monitoring"
# get active node counters
if {$::script_parameters::verbose} {
	puts stderr "Getting counters page $::script_parameters::node/$::script_parameters::counters_page"
}
if [catch {http::geturl "$::script_parameters::node/$::script_parameters::counters_page"} status_token] {
	# unable to connect
	if {$::script_parameters::verbose} {
		puts stderr "unable to connect to $::script_parameters::node/$::script_parameters::counters_page"
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
package require opsparsers 0.2
array set counters_array [::opsparsers::json2array [http::data $status_token]]
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
	# in threshold list item 0 - counter regexp 
	# 1 - min/max/equal/notequal
	# 2 - error value 3 - warning value
	# get matched components
	# get matched counters
	foreach counter [array names counters_array -regexp [lindex $threshold 0]] {
		# add needed value to array
		if {[array names result_array -exact $counter] == {}} {
			set result_array($counter) [list $counters_array($counter) "$counter = $counters_array($counter)"]
			if !$::script_parameters::cacti_output {
				# check counter value
				switch -exact -- [lindex $threshold 1] {
					"min" {
						set comparison "<="
					}
					"tsmax" {
						set time [clock seconds]
						set ts [lindex $result_array($counter) 0]
						set diff [expr int($time - $ts)]
						set result_array($counter) [list $diff "$counter = $diff"]
						set comparison ">="
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
				if {[expr [lindex $result_array($counter) 0] $comparison [lindex $threshold 2]]} {
					# error value
					if {$exit_code != $EXIT_ERROR} {
						set exit_code $EXIT_ERROR
						set exit_message "ERROR - $counter equal to [lindex $result_array($counter) 0] but [lindex $threshold 1] is [lindex $threshold 2]"
					}
				} elseif {[expr [lindex $result_array($counter) 0] $comparison [lindex $threshold 3]]} {
					# warning value
					if {($exit_code != $EXIT_ERROR) && ($exit_code != $EXIT_WARNING)} {
						set exit_code $EXIT_WARNING
						set exit_message "WARNING - $counter equal to [lindex $result_array($counter) 0] but [lindex $threshold 1] is [lindex $threshold 3]"
					}
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
