#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# define tcl prefer version \
TCL=tclsh
# prefer versions 8.2 -> 8.3 -> 8.4 -> 8.6 -> 8.5 \
for v in 8.2 8.3 8.4 8.6 8.5; do type tclsh$v >/dev/null 2>&1 && TCL=tclsh$v; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

######################################################################
# KFA-321 - wmi_counters.sh check values which received via WMI
#
# This script checks values of specified Windows parameters which
# received as result of WMI queue. Data are returned in nagios format
# with perfdata or in cacti mode.
#
# Algorithm:
# 1) run wmi queue
# 2) find matched counters
# 3) if work in nagios mode - check counters values
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
# Maksym Tiurin (mtiurin@cisco.com) 08/07/2013
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
	variable wmi_host ""
	variable wmi_user "nagios"
	variable wmi_password "BKidKOEXoW8s"
	variable wmi_domain "vm"
	variable wmi_workgroup ""
	variable retry_count 2
	variable queries {}
	variable counters_thresholds {".* .* text match .* .*"}
	variable allow_empty 0
	variable int_as_time 0
	variable cacti_output 0
	variable text_output 0
	variable reduce_names 0
}

set USAGE "USAGE:
	[file tail $argv0] \[OPTIONS\]

Check service counters in MySQL DB.

Options
	-h/--help         Show this help screen
	-v/--verbose      Turn [::opscfg::bool2text [expr ! $::script_parameters::verbose]] verbose mode (default [::opscfg::bool2text $::script_parameters::verbose])
	-H/--host         Windows hostname to connect
	-u/--user         Windows user to connect (default: $::script_parameters::wmi_user)
	-p/--password     Windows password to connect (default: $::script_parameters::wmi_password)
	-d/--domain       Windows domain to use (default: $::script_parameters::wmi_domain)
	--workgroup       Windows workgroup to use (default: $::script_parameters::wmi_workgroup)
	-R/--retry-count  WMI connection attempts (default: $::script_parameters::retry_count)
	-q/--query        WMI query to execute
	                  This option can be specified multiple times
	-t/--thresholds   Counters thresholds for nagios specified using following format: \"wmi_class_regexp counter_regexp counter_type min/max/equal/notequal/match/notmatch error_value \[warning_value\]\"
	                  where counter type one of numeric/datetime/text (numeric for all integer, float, double values and datetime for all time, date, timestamp values).
	                  For datetime counter check values specified in seconds till now. For text counters applicable only match/notmatch checks.
	                  Suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
	                  This option can be specified multiple times (default $::script_parameters::counters_thresholds)
	-E/--allow-empty  Turn [::opscfg::bool2text [expr ! $::script_parameters::allow_empty]] mode that do not return ERROR when one of specified thresholds is not find (default: [::opscfg::bool2text $::script_parameters::allow_empty])
	-I/--int-as-time  Turn [::opscfg::bool2text [expr ! $::script_parameters::int_as_time]] process integer database values as UNIXtime values (default [::opscfg::bool2text $::script_parameters::int_as_time])
	-r/--reducenames  Turn [::opscfg::bool2text [expr ! $::script_parameters::reduce_names]] reduce names of cacti field names and nagios perfdata names to 19 chars (default [::opscfg::bool2text $::script_parameters::reduce_names])
	-c/--cacti        Turn [::opscfg::bool2text [expr ! $::script_parameters::cacti_output]] cacti type output (default [::opscfg::bool2text $::script_parameters::cacti_output])
	-T/--text         Turn [::opscfg::bool2text [expr ! $::script_parameters::text_output]] tab separated text output (overrides cacti and nagios mode) (default [::opscfg::bool2text $::script_parameters::text_output])
	                  When script works in this mode it does not check counters values.

Examples:

  [file tail $argv0] -H prod-vdb-lon5-1.vm.ironport.com -q \"select * from Win32_PerfRawData_PerfOS_System\" \\
  -t \"Win32_PerfRawData_PerfOS_System Processes numeric max 100 90\" -t \"Win32_PerfRawData_PerfOS_System Threads numeric max 1000 900\" --allow-empty
 Run specified queries on host, check returned result and print result in Nagios format
 (when processes count >= 100 or threads count >= 1000 - ERROR, when processes count >= 90 or threads count >= 900 - WARNING, else OK include when counter does not exist).

  [file tail $argv0] -H prod-vdb-lon5-1.vm.ironport.com -q \"select * from Win32_PerfRawData_PerfOS_System\" \\
  -t \"Win32_PerfRawData_PerfOS_System Processes numeric max 100 90\" -t \"Win32_PerfRawData_PerfOS_System Threads numeric max 1000 900\"
 The same but return ERROR when specified threshold does not exist.
 (when processes count >= 100 or threads count >= 1000 - ERROR, when processes count >= 90 or threads count >= 900 - WARNING, else OK).

  [file tail $argv0] -H prod-vdb-lon5-1.vm.ironport.com -q \"select * from Win32_PerfRawData_PerfOS_System\" \\
  -t \"Win32_PerfRawData_PerfOS_System Processes numeric max 100 90\" -t \"Win32_PerfRawData_PerfOS_System Threads numeric max 1000 900\" --cacti
 The same but return counters in Cacti format without values check.

  [file tail $argv0] -H prod-vdb-lon5-1.vm.ironport.com -q \"select * from Win32_PerfRawData_PerfOS_System\" \\
  -t \"Win32_PerfRawData_PerfOS_System Processes numeric max 100 90\" -t \"Win32_PerfRawData_PerfOS_System Threads numeric max 1000 900\" --text
 The same but return counter in tab separated format without values check
"

# parse CLI options
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit 0
}
::opscfg::getswitchopt argv [list "-v" "--verbose"] ::script_parameters::verbose
::opscfg::getswitchopt argv [list "-E" "--allow-empty"] ::script_parameters::allow_empty
::opscfg::getswitchopt argv [list "-I" "--int-as-time"] ::script_parameters::int_as_time
::opscfg::getopt argv [list "-H" "--host"] ::script_parameters::wmi_host
::opscfg::getopt argv [list "-u" "--user"] ::script_parameters::wmi_user
::opscfg::getopt argv [list "-p" "--password"] ::script_parameters::wmi_password
::opscfg::getopt argv [list "-d" "--domain"] ::script_parameters::wmi_domain
::opscfg::getopt argv [list "--workgroup"] ::script_parameters::wmi_workgroup
::opscfg::getopt argv [list "-R" "--retry-count"] ::script_parameters::retry_count
::opscfg::getswitchopt argv [list "-c" "--cacti"] ::script_parameters::cacti_output
::opscfg::getswitchopt argv [list "-T" "--text"] ::script_parameters::text_output
::opscfg::getswitchopt argv [list "-r" "--reducenames"] ::script_parameters::reduce_names

while {[::opscfg::getopt argv [list "-t" "--thresholds"] threshold]} {
	# threshold specification: "wmi_class_regexp counter_regexp counter_type min/max/equal/notequal/match/notmatch error_value \[warning_value\]"
	set threshold_list [split $threshold]
	if {[llength $threshold_list] < 5} {
		puts stderr "Invalid threshold specification \"$threshold\""
		puts $USAGE
		exit $EXIT_UNKNOWN
	}
	# check counter_type
	switch -exact -- [lindex $threshold_list 2] {
		"text" {
			set counter_type "text"
		}
		"datetime" {
			set counter_type "datetime"
		}
		default {
			set counter_type "numeric"
		}
	}
	switch -exact -- [lindex $threshold_list 3] {
		"match" {
			set check_type "match"
		}
		"notmatch" {
			set check_type "notmatch"
		}
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
	if {($counter_type == "text") && ![string match "*match" $check_type]} {
		puts stderr "Invalid threshold specification \"$threshold\""
		puts stderr "text thresholds support match/notmatch"
		puts $USAGE
		exit $EXIT_UNKNOWN
	}
	set counter_error [lindex $threshold_list 4]
	if {[llength $threshold_list] >= 6} {
		set counter_warning [lindex $threshold_list 5]
	} else {
		set counter_warning $counter_error
	}
	if {$counter_type == "datetime"} {
		# expand and calculate value
		set counter_error [expr [clock seconds] - [::opscfg::expandtime $counter_error]]
		set counter_warning [expr [clock seconds] - [::opscfg::expandtime $counter_warning]]
	}
	# add threshold to list
	lappend new_counters_thresholds [list [lindex $threshold_list 0] [lindex $threshold_list 1] $counter_type $check_type $counter_error $counter_warning]
}
if [info exists new_counters_thresholds] {
	set ::script_parameters::counters_thresholds $new_counters_thresholds
}
while {[::opscfg::getopt argv [list "-q" "--query"] query]} {
	if [regexp -expanded -nocase {^\s*select\s+.*} $query] {
		# add queue to list
		lappend ::script_parameters::queries $query
	} elseif $::script_parameters::verbose {
		puts stderr "Skip bad query \"$query\""
	}
}
# check that all params are present
foreach v [info vars ::script_parameters::*] {
	if {[set [set v]] == ""} {
		if {($v != "::script_parameters::wmi_domain") && ($v != "::script_parameters::wmi_workgroup")} {
			puts stderr "parameter [namespace tail $v] value should be set"
			exit $EXIT_UNKNOWN
		}
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
package require monwmi
package require monoutput 0.3
# make string to create wmi client
set wmiclient [list "::monwmi::openwmi" "-retry" "$::script_parameters::retry_count" "-host" "$::script_parameters::wmi_host"]
lappend wmiclient "-username" "$::script_parameters::wmi_user" "-password" "$::script_parameters::wmi_password"
if {$::script_parameters::wmi_domain != ""} {
	lappend wmiclient "-domain" "$::script_parameters::wmi_domain"
}
if {$::script_parameters::wmi_workgroup != ""} {
	lappend wmiclient "-workgroup" "$::script_parameters::wmi_workgroup"
}
# create wmi client
set wmi_client [eval [lrange $wmiclient 0 end]]
unset wmiclient
# list for WMI results
set WMI_data_list {}
# run queries
foreach query $::script_parameters::queries {
	# run query
	if $::script_parameters::verbose {
		puts stderr "Run query: \"$query\""
	}
	if [catch {::monwmi::wmi -wmiId $wmi_client -- $query} result] {
		# got error
		if $::script_parameters::verbose {
			global errorInfo
			puts stderr "Query execution error: $errorInfo"
		}
		if {(!$::script_parameters::cacti_output) && (!$::script_parameters::text_output)} {
			::monoutput::nagiosoutput "ERROR - WMI query execution failed"
		}
		exit $EXIT_ERROR
	} else {
		# add result to data list
		set WMI_data_list [concat $WMI_data_list $result]
	}
}
# close client
::monwmi::closewmi $wmi_client
if $::script_parameters::verbose {
	puts stderr "Got following data from WMI:"
	puts stderr $WMI_data_list
}
# format result array
array unset result_array
array set WMI_data_array $WMI_data_list
unset WMI_data_list
set exit_code $EXIT_OK
set exit_message "OK"
proc check_type {value {type numeric}} {
	if {$type == "text"} {
		return 1
	} elseif {$type == "datetime"} {
		# check is value a date/time/datetime
		if {[regexp -expanded {^\d+$} $value] && (!$::script_parameters::int_as_time)} {
			return 0
		} else {
			return [expr ! [catch {clock scan $value} result]]
		}
	} else {
		# check is value a numeric
		return [string is double $value]
	}
}
foreach threshold $::script_parameters::counters_thresholds {
	# in threshold list item 
	# 0 - wmi class regexp,
	# 1 - counter regexp,
	# 2 - counter type
	# 3 - comparison 
	# 4 - error threshold
	# 5 - warning threshold
	# get matched counters
	set matched_counter 0
	# loop thru matched WMI classes
	foreach wmi_class [array names WMI_data_array -regexp [lindex $threshold 0]] {
		if {$WMI_data_array($wmi_class) == {}} {
			# skip empty record
			continue
		}
		array unset record_array
		array set record_array $WMI_data_array($wmi_class)
		set matched_counter 0
		# loop thru matched counters
		foreach counter [array names record_array -regexp [lindex $threshold 1]] {
			# check counter type
			if [check_type $record_array($counter) [lindex $threshold 2]] {
				# needed counter
				set matched_counter 1
				# add needed value to array
				set result_array_key [list $wmi_class $counter]
				if {[array names result_array -exact $result_array_key] == {}} {
					if {[lindex $threshold 2] == "datetime"} {
						set result_array($result_array_key) [list [clock scan $record_array($counter)] "$result_array_key = $record_array($counter)"]
					} else {
						set result_array($result_array_key) [list $record_array($counter) "$result_array_key = $record_array($counter)"]
					}
				}
				if {(!$::script_parameters::cacti_output) && (!$::script_parameters::text_output)} {
					# check counter value
					switch -exact -- [lindex $threshold 3] {
						"match" {
							set comparison "match"
						}
						"notmatch" {
							set comparison "notmatch"
						}
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
					# make comparison expression
					switch -exact -- $comparison {
						"match" {
							set error_comparison [list "regexp" "-expanded" "--" [lindex $threshold 4] [lindex $result_array($result_array_key) 0]]
							set warning_comparison [list "regexp" "-expanded" "--" [lindex $threshold 5] [lindex $result_array($result_array_key) 0]]
						}
						"notmatch" {
							set error_comparison [list "!" "regexp" "-expanded" "--" [lindex $threshold 4] [lindex $result_array($result_array_key) 0]]
							set warning_comparison [list "!" "regexp" "-expanded" "--" [lindex $threshold 5] [lindex $result_array($result_array_key) 0]]
						}
						default {
							set error_comparison [list "expr" [lindex $result_array($result_array_key) 0] $comparison [lindex $threshold 4]]
							set warning_comparison [list "expr" [lindex $result_array($result_array_key) 0] $comparison [lindex $threshold 5]]
						}
					}
					if {[eval [lrange $error_comparison 0 end]]} {
						# error value
						if {$exit_code != $EXIT_ERROR} {
							set exit_code $EXIT_ERROR
							if {[lindex $threshold 2] == "datetime"} {
								# convert unix time to text
								set exit_message "ERROR - $result_array_key equal to [clock format [lindex $result_array($result_array_key) 0] -format {%Y-%m-%dT%H:%M:%S}] but [lindex $threshold 3] is [clock format [lindex $threshold 4] -format {%Y-%m-%dT%H:%M:%S}]"
							} else {
								set exit_message "ERROR - $result_array_key equal to [lindex $result_array($result_array_key) 0] but [lindex $threshold 3] is [lindex $threshold 4]"
							}
						}
					} elseif {[eval [lrange $warning_comparison 0 end]]} {
						# warning value
						if {($exit_code != $EXIT_ERROR) && ($exit_code != $EXIT_WARNING)} {
							set exit_code $EXIT_WARNING
							if {[lindex $threshold 2] == "datetime"} {
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
	}
	if {(!$::script_parameters::allow_empty) && (!$matched_counter)} {
		set exit_code $EXIT_ERROR
		set exit_message "Threshold \"$threshold\" did not find in the counters"
	}
}
# print result
if $::script_parameters::text_output {
	::monoutput::textoutput [array get result_array]
	exit $EXIT_OK
}
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
