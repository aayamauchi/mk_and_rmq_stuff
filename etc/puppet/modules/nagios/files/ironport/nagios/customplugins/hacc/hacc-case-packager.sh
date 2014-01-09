#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# define tcl version \
TCL=tclsh
# prefered versions 8.4 -> 8.6 -> 8.5 \
for v in 8.4 8.6 8.5; do type tclsh$v >/dev/null 2>&1 && TCL=tclsh$v; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

# HACC Case Packager Monitoring Node Checks
# Eng Owner: Michael Parker <parker@ironport.com>
# MonOps: Valerii Kafedzhy <vkafedzh@cisco.com>
# See MONOPS-1411
# Spec: http://eng.ironport.com/docs/is/case-cluster/monitoring.rst
#==============================================================================
# # Maksym Tiurin (mtiurin@cisco.com) 05/14/2013

# add path to shared library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path "../lib"]

# load module which provides exit codes and functions for format output
package require monoutput 0.2
# import CLI & config parser
package require opscfg

# default values
namespace eval script_parameters {
	variable verbose 0
	variable timeout 3000
	variable host "http://downloads-external.ironport.com/as/case.ini?serial=case_cluster"
	variable critical 30m
	variable warning 29m
}

set USAGE "USAGE:
	[file tail $argv0] \[OPTIONS\]

HACC Case Packager Status Check.

Options
	-h/--help         Show this help screen
	-v/--verbose      Verbose mode (default: [::opscfg::bool2text $::script_parameters::verbose])
	-H/--host         URL to get (default: $::script_parameters::host)
	-t/--timeout      Timeout for retrieving URL in milliseconds (default: $::script_parameters::timeout)
	-c/--critical     Critical threshold (default: $::script_parameters::critical)
	-w/--warning      Warning threshold (default: $::script_parameters::warning)
	                  You can use suffixes in thresholds.
	                  Suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
"

# parse CLI options
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit $EXIT_OK
}
if [::opscfg::getopt argv [list "-v" "--verbose"]] {
	set ::script_parameters::verbose 1
}

::opscfg::getopt argv [list "-H" "--host"] ::script_parameters::host $::script_parameters::host
::opscfg::getopt argv [list "-t" "--timeout"] ::script_parameters::timeout $::script_parameters::timeout
::opscfg::getopt argv [list "-c" "--critical"] ::script_parameters::critical $::script_parameters::critical
::opscfg::getopt argv [list "-w" "--warning"] ::script_parameters::warning $::script_parameters::warning
# check time
if [catch {::opscfg::expandtime $::script_parameters::critical} ::script_parameters::critical] {
	puts stderr "Bad time value specified for critical threshold"
	exit $EXIT_UNKNOWN
}
if [catch {::opscfg::expandtime $::script_parameters::warning} ::script_parameters::warning] {
	puts stderr "Bad time value specified for warning threshold"
	exit $EXIT_UNKNOWN
}
if {$::script_parameters::warning > $::script_parameters::critical} {
	puts stderr "Critical threshold should be more that warning"
	exit $EXIT_UNKNOWN
}
# check host
if ![regexp -expanded {^http://.*} $::script_parameters::host] {
	puts stderr "Invalid host URL specified"
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

if {$::script_parameters::verbose} {
	puts stderr "Getting page $::script_parameters::host"
}
if [catch {http::geturl $::script_parameters::host -timeout $::script_parameters::timeout} status_token] {
	# unable to connect
	if {$::script_parameters::verbose} {
		puts stderr "unable to connect to $::script_parameters::host"
		global errorCode
		puts stderr "exit code $errorCode"
		puts stderr "output: $status_token"
	}
	::monoutput::nagiosoutput "ERROR - Unable to connect"
	exit $EXIT_ERROR
}
# check status
if ![regexp {^HTTP.*200\s+OK$} [http::code $status_token]] {
	# error when getting node status
	if {$::script_parameters::verbose} {
		puts stderr "page return code: \"[http::code $status_token]\""
	}
	::monoutput::nagiosoutput "ERROR - Unable to get URL"
	exit $EXIT_ERROR
}
# get server date
array unset meta
array set meta [set [set status_token](meta)]
set server_date [clock scan $meta(Last-Modified)]
# get case-update version
regexp -expanded {\[case-update\]\nversion\s+=\s+([^\n]*?)\n} [http::data $status_token] match case_update
# convert to unixtime
set case_update [clock scan [string map {_ \ } $case_update] -gmt 1]
# clean token
http::cleanup $status_token
# check thresholds
if $::script_parameters::verbose {
	puts stderr "Server date: $server_date"
	puts stderr "Case update: $case_update"
}
if {$server_date >= [expr $case_update + $::script_parameters::critical]} {
	::monoutput::nagiosoutput "ERROR - Case update older than critical threshold"
	exit $EXIT_ERROR
} elseif {$server_date >= [expr $case_update + $::script_parameters::warning]} {
	::monoutput::nagiosoutput "WARNING - Case update older than warning threshold"
	exit $EXIT_WARNING
} else {
	::monoutput::nagiosoutput "OK - Case update is OK"
	exit $EXIT_OK
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
