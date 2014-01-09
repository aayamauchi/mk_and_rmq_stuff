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
# MONOPS-1362 - mysql_counters.sh check services counters in MySQL DB.
#
# This script checks service specified counters in the MySQL database
# and return data in nagios format with perfdata or in cacti mode.
#
# Algorithm:
# 1) run sql queue
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
# Maksym Tiurin (mtiurin@cisco.com) 05/29/2013
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
	variable database ""
	variable database_host ""
	variable database_port "3306"
	variable database_user "reader"
	variable database_password "sekr!t"
	variable retry_count 2
	variable queries {}
	variable counters_thresholds {".*error.* numeric max 3 2"}
	variable allow_empty 0
	variable int_as_time 0
	variable cacti_output 0
	variable reduce_names 0
}

set USAGE "USAGE:
	[file tail $argv0] \[OPTIONS\]

Check service counters in MySQL DB.

Options
	-h/--help         Show this help screen
	-v/--verbose      Verbose mode (default: [::opscfg::bool2text $::script_parameters::verbose])
	-d/--db           MySQL database name
	-H/--host         MySQL hostname to connect
	-P/--port         MySQL port to connect (default: $::script_parameters::database_port)
	-u/--user         MySQL user to connect (default: $::script_parameters::database_user)
	-p/--password     MySQL password to connect (default: $::script_parameters::database_password)
	-R/--retry-count  MySQL connection attempts (default: $::script_parameters::retry_count)
	-q/--query        SQL query to execute
	                  This option can be specified multiple times
	-t/--thresholds   Counters thresholds for nagios specified using following format: \"counter_regexp counter_type min/max/equal/nonequal error_value \[warning_value\]\"
	                  where counter type one of numeric/datetime (numeric for all integer, float, double values and datetime for all time, date, timestamp values).
	                  For datetime counter check values specified in seconds till now.
	                  Suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
	                  This option can be specified multiple times (default $::script_parameters::counters_thresholds)
	-E/--allow-empty  Do not return ERROR when one of specified thresholds is not find (default: [::opscfg::bool2text $::script_parameters::allow_empty])
	-I/--int-as-time  Process integer database values as UNIXtime values (default [::opscfg::bool2text $::script_parameters::int_as_time])
	-r/--reducenames  Reduce names of cacti field names and nagios perfdata names to 19 chars (default [::opscfg::bool2text $::script_parameters::reduce_names])
	-c/--cacti        Cacti type output (default [::opscfg::bool2text $::script_parameters::cacti_output])

Examples:

  [file tail $argv0] -H prod-trafficcorpus-db-m1.vega.ironport.com -d traffic_corpus -u reader -p reader_password -E \\
  -q \"select value as unexpected_errors from counters where name='unexpected_errors' and host='prod-trafficcorpus-app1.vega.ironport.com'\" \\
  -q \"select value as replication_errors from counters where name='replication_errors' and host='prod-trafficcorpus-app1.vega.ironport.com\" \\
  -t \".*_errors numeric max 3 2\"
 Run specified queries on traffic_corpus database, check returned result and print result in Nagios format
 (when error counter value >= 3 - ERROR, when error counter value = 2 - WARNING, else OK include when counter does not exist).

  [file tail $argv0] -H prod-trafficcorpus-db-m1.vega.ironport.com -d traffic_corpus -u reader -p reader_password \\
  -q \"select value as unexpected_errors from counters where name='unexpected_errors' and host='prod-trafficcorpus-app1.vega.ironport.com'\" \\
  -q \"select value as replication_errors from counters where name='replication_errors' and host='prod-trafficcorpus-app1.vega.ironport.com\" \\
  -t \".*_errors numeric max 3 2\"
 The same but return ERROR when specified threshold does not exist.
 (when error counter value >= 3 - ERROR, when error counter value = 2 - WARNING, else OK).

  [file tail $argv0] -H prod-trafficcorpus-db-m1.vega.ironport.com -d traffic_corpus -u reader -p reader_password \\
  -q \"select value as unexpected_errors from counters where name='unexpected_errors' and host='prod-trafficcorpus-app1.vega.ironport.com'\" \\
  -q \"select value as replication_errors from counters where name='replication_errors' and host='prod-trafficcorpus-app1.vega.ironport.com\" \\
  -t \".*_errors numeric max 3 2\" -c
 The same but return counters in Cacti format without values check.
"

# parse CLI options
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit 0
}
if [::opscfg::getopt argv [list "-v" "--verbose"]] {
	set ::script_parameters::verbose 1
}
if [::opscfg::getopt argv [list "-E" "--allow-empty"]] {
	set ::script_parameters::allow_empty 1
}
if [::opscfg::getopt argv [list "-I" "--int-as-time"]] {
	set ::script_parameters::int_as_time 1
}
::opscfg::getopt argv [list "-d" "--db"] ::script_parameters::database
::opscfg::getopt argv [list "-H" "--host"] ::script_parameters::database_host
::opscfg::getopt argv [list "-P" "--port"] ::script_parameters::database_port
::opscfg::getopt argv [list "-u" "--user"] ::script_parameters::database_user
::opscfg::getopt argv [list "-p" "--password"] ::script_parameters::database_password
::opscfg::getopt argv [list "-R" "--retry-count"] ::script_parameters::retry_count
if {[::opscfg::getopt argv [list "-c" "--cacti"]]} {
	set ::script_parameters::cacti_output 1
}
if [::opscfg::getopt argv [list "-r" "--reducenames"]] {
	set ::script_parameters::reduce_names 1
}
while {[::opscfg::getopt argv [list "-t" "--thresholds"] threshold]} {
	# threshold specification: "counter_regexp counter_type min/max/equal/nonequal error_value \[warning_value\]"
	set threshold_list [split $threshold]
	if {[llength $threshold_list] < 4} {
		puts stderr "Invalid threshold specification \"$threshold\""
		puts $USAGE
		exit $EXIT_UNKNOWN
	}
	# check counter_type
	switch -exact -- [lindex $threshold_list 1] {
		"datetime" {
			set counter_type "datetime"
		}
		default {
			set counter_type "numeric"
		}
	}
	switch -exact -- [lindex $threshold_list 2] {
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
	set counter_error [lindex $threshold_list 3]
	if {[llength $threshold_list] >= 5} {
		set counter_warning [lindex $threshold_list 4]
	} else {
		set counter_warning $counter_error
	}
	if {$counter_type == "datetime"} {
		# expand and calculate value
		set counter_error [expr [clock seconds] - [::opscfg::expandtime $counter_error]]
		set counter_warning [expr [clock seconds] - [::opscfg::expandtime $counter_warning]]
	}
	# add threshold to list
	lappend new_counters_thresholds [list [lindex $threshold_list 0] $counter_type $check_type $counter_error $counter_warning]
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
package require opsdb
package require mondiablo 0.2
# create mysql client
set mysql_client [::opsdb::openmysql -retry $::script_parameters::retry_count \
                    -host $::script_parameters::database_host \
                    -port $::script_parameters::database_port \
                    -username $::script_parameters::database_user \
                    -password $::script_parameters::database_password \
                    -database $::script_parameters::database]
# list for DB results
set DB_data_list {}
# run queries
foreach query $::script_parameters::queries {
	# run query
	if $::script_parameters::verbose {
		puts stderr "Run query: \"$query\""
	}
	if [catch {::opsdb::mysql -mysqlId $mysql_client -- $query} result] {
		# got error
		if $::script_parameters::verbose {
			global errorInfo
			puts stderr "Query execution error: $errorInfo"
		}
		if {!$::script_parameters::cacti_output} {
			::monoutput::nagiosoutput "ERROR - SQL query execution failed"
		}
		exit $EXIT_ERROR
	} else {
		# add result to data list
		set DB_data_list [concat $DB_data_list $result]
	}
}
# close client
::opsdb::closemysql $mysql_client
if $::script_parameters::verbose {
	puts stderr "Got following data from DB:"
	puts stderr $DB_data_list
}
# format result array
array unset result_array
set exit_code $EXIT_OK
set exit_message "OK"
proc check_type {value {type numeric}} {
	if {$type == "datetime"} {
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
	# in threshold list item 0 - counter regexp,
	# 1 - counter type
	# 2 - comparison 
	# 3 - error threshold
	# 4 - warning threshold
	# get matched counters
	set matched_counter 0
	foreach record $DB_data_list {
		if {$record == {}} {
			# skip empty records
			continue
		}
		array unset record_array
		array set record_array $record
		set matched_counter 0
		foreach counter [array names record_array -regexp [lindex $threshold 0]] {
			# check counter type
			if [check_type $record_array($counter) [lindex $threshold 1]] {
				# needed counter
				set matched_counter 1
				# add needed value to array
				set result_array_key $counter
				if {[array names result_array -exact $result_array_key] == {}} {
					if {[lindex $threshold 1] == "datetime"} {
						set result_array($result_array_key) [list [clock scan $record_array($counter)] "$result_array_key = $record_array($counter)"]
					} else {
						set result_array($result_array_key) [list $record_array($counter) "$result_array_key = $record_array($counter)"]
					}
				}
				if !$::script_parameters::cacti_output {
					# check counter value
					switch -exact -- [lindex $threshold 2] {
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
					if {[expr [lindex $result_array($result_array_key) 0] $comparison [lindex $threshold 3]]} {
						# error value
						if {$exit_code != $EXIT_ERROR} {
							set exit_code $EXIT_ERROR
							if {[lindex $threshold 1] == "datetime"} {
								# convert unix time to text
								set exit_message "ERROR - $result_array_key equal to [clock format [lindex $result_array($result_array_key) 0] -format {%Y-%m-%dT%H:%M:%S}] but [lindex $threshold 2] is [clock format [lindex $threshold 3] -format {%Y-%m-%dT%H:%M:%S}]"
							} else {
								set exit_message "ERROR - $result_array_key equal to [lindex $result_array($result_array_key) 0] but [lindex $threshold 2] is [lindex $threshold 3]"
							}
						}
					} elseif {[expr [lindex $result_array($result_array_key) 0] $comparison [lindex $threshold 4]]} {
						# warning value
						if {($exit_code != $EXIT_ERROR) && ($exit_code != $EXIT_WARNING)} {
							set exit_code $EXIT_WARNING
							if {[lindex $threshold 1] == "datetime"} {
								# convert unix time to text
								set exit_message "WARNING - $result_array_key equal to [clock format [lindex $result_array($result_array_key) 0] -format {%Y-%m-%dT%H:%M:%S}] but [lindex $threshold 2] is [clock format [lindex $threshold 4] -format {%Y-%m-%dT%H:%M:%S}]"
							} else {
								set exit_message "WARNING - $result_array_key equal to [lindex $result_array($result_array_key) 0] but [lindex $threshold 2] is [lindex $threshold 4]"
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
