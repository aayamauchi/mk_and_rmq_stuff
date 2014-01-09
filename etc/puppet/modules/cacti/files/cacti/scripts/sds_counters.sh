#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# define tcl prefer version \
TCL=tclsh
# prefer Tcl versions 8.5, 8.6, 8.4 (monoutput require 8.4+) \
for v in 8.5 8.6 8.4; do type tclsh$v >/dev/null 2>&1 && { TCL=tclsh$v; break; } ; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

# Developed by Valerii Kafedzhy (vkafedzh@cisco.com)
# Date 01/27/13
# Rewritten by Maksym Tiurin (mtiurin@cisco.com)
# Date 06/12/13
# Ticket: MONOPS-485

# add path to shared library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path "lib"]
# load module which provides exit codes and functions for format output
package require monoutput

set usage "usage: [file tail $argv0] hostname

Gather SDS counts from prod-sds-db-m1.vega.ironport.com

Hostname:
e.g.: prod-sds-app3.vega.ironport.com"

if {$argc == 0} {
	puts $usage
	exit $EXIT_UNKNOWN
}

set hostname [lindex $argv 0]

set counters_list {"sds.total_requests" "sds.total_score_requests" "sds.total_web_requests" "sds.total_email_requests" \
                     "sds.total_telemetry_requests" "sds.total_dataset_requests" "sds.total_labels_requests" \
                     "sds.total_status_requests" "sds.total_bad_api_req" "sds.unauthed_service_reqs" \
                     "memcache.hit_response_time_microseconds" \
                     "memcache.miss_response_time_microseconds" "sbrs.response_time_microseconds"}

array unset result_array
foreach counter $counters_list {
	set result [split \
	              [lsearch -inline -regexp \
	                 [split \
	                    [exec [file join $script_path check_sds_counts.py] -c prod-sds-db-m1.vega.ironport.com nagios thaxu1T sds_vector check_value $counter]] \
	                 "^${hostname}:"] \
	              ":"]
	set result_array($counter) [lindex $result 1]
}
::monoutput::cactioutput -reducenames -- [array get result_array]

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
