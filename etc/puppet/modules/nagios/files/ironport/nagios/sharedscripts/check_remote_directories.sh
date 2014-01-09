#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# define tcl prefer version \
TCL=tclsh
# prefer Tcl versions 8.5, 8.6, 8.4 (monoutput require 8.4+) \
for v in 8.5 8.6 8.4; do type tclsh$v >/dev/null 2>&1 && { TCL=tclsh$v; break; } ; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

######################################################################
# MONOPS-396 - check_remote_directories.sh check subdirectories size
# and mtime on remote server
#
# This scripts checks subdirectories size and/or mtime for specified
# directories and return data in nagios format with perfdata or in
# cacti mode.
#
# Return codes and their meaning:
#    Nagios:
#           0 (ok)
#           2 (critical) - when specified directory does not contain
#                          matched subdirectories or ssh can not
#                          connect to remote host
#           3 (unknown) - when specified bad CLI options or no data returned
#
#    Cacti:
#           0 (ok)
#           2 (critical) - when ssh can not connect to remote host
#           3 (unknown) - when specified bad CLI options or no data returned
#
# Output:
#    Nagios:
#           OK/ERROR - directory1 [size] [mtime in %Y-%m-%d format]; | directory1=perfdata
#           directory2 [size] [mtime in %Y-%m-%d format];
#           directory3 [size] [mtime in %Y-%m-%d format];
#           ...
#           directoryN [size] [mtime in %Y-%m-%d format]; | directory2=perfdata
#           directory3=perfdata
#           ...
#           directoryN=perfdata
#
#           where size, mtime and perfdata showed for matched subdirectory
#    Cacti:
#          directory1:size directory2:size ... directoryN:size
#
#          where size showed for matched subdirectory
#
# Maksym Tiurin (mtiurin@cisco.com) 05/31/2013
######################################################################

# add path to shared library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path "lib"]

# load module which provides exit codes and functions for format output
package require monoutput
# import CLI & config parser
package require opscfg 1.1

# default values
namespace eval script_parameters {
	variable verbose 0
	variable latest 0
	variable host ""
	variable username "nagios"
	variable password ""
	variable directory ""
	variable retry_count 2
	variable thresholds {""}
	variable cacti_output 0
	variable reduce_names 0
	variable freebsd 0
	variable trim_common 1
	variable match_all 0
}


set USAGE "
USAGE:
	[file tail $argv0] \[OPTIONS\]

Check directories size, date and available on remote host. Return error if checked directory does not contain subdirectory matched for all criteria.

Options
	-h/--help         Show this help screen
	-H/--host         Hostname to check
	-u/--username     Username to login (default $::script_parameters::username)
	-p/--password     Password to login or filename of file with password in the first line (default $::script_parameters::password)
	                  When password is empty - ssh key without password should be used.
	-d/--directory    Base directory to check.
	                  This option can be specified multiple times.
	-l/--latest       Turn [::opscfg::bool2text [expr ! $::script_parameters::latest]] check only latest subdirectory and use directory path as field and perfdata names (default [::opscfg::bool2text $::script_parameters::latest])
	-R/--retry-count  SSH connection attempts (default: $::script_parameters::retry_count)
	-t/--thresholds   Directories thresholds for nagios specified using following format: \"directory_regexp subdirectory_regexp check_type min/max/equal/nonequal error_value \[warning_value\]\"
	                  where check type one of size/mtime.
	                  For mtime check values specified in seconds till now.
	                  Suffix for size may be 'b' for bytes (the default), 'k' for kilobytes, 'm' for megabytes or 'g' for gigabytes.
	                  Suffix for mtime may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
	                  This option can be specified multiple times (default $::script_parameters::thresholds)
	-F/--freebsd      Turn [::opscfg::bool2text [expr ! $::script_parameters::freebsd]] FreeBSD compatible ls options (default [::opscfg::bool2text $::script_parameters::freebsd])
	-v/--verbose      Turn [::opscfg::bool2text [expr ! $::script_parameters::verbose]] verbose mode (default [::opscfg::bool2text $::script_parameters::verbose])
	-r/--reducenames  Turn [::opscfg::bool2text [expr ! $::script_parameters::reduce_names]] reducing names of cacti field names and nagios perfdata names to 19 chars (default [::opscfg::bool2text $::script_parameters::reduce_names])
	-T/--trim-common  Turn [::opscfg::bool2text [expr ! $::script_parameters::trim_common]] trimming of common path part in cacti field names and nagios perfdata names (default [::opscfg::bool2text $::script_parameters::trim_common])
	                  For example /the/full/path/foo and /the/full/path/bar are trimmed to foo and bar.
	-A/--match-all    Turn [::opscfg::bool2text [expr ! $::script_parameters::match_all]] requirement of matching all types of thresholds for each record (default [::opscfg::bool2text $::script_parameters::match_all])
	                  When this option is turned on 'AND' statement is used for thresholds types.
	-c/--cacti        Turn [::opscfg::bool2text [expr ! $::script_parameters::cacti_output]] cacti type output (default [::opscfg::bool2text $::script_parameters::cacti_output])
	                  Applicable for size only

Examples
 [file tail $argv0] -H ops-backuprestore-db-m1.vega.ironport.com -d '/mnt/vega_db_backups/prod-wbrsrule-db-s2-1/mysql/full-backups' -t '.* \\d+_\\d+ size min 500k' -t '.* \\d+_\\d+ mtime min 2d'
  Checks backup directories for wbrsrule on host ops-backuprestore-db-m1.vega.ironport.com and write output in nagios format.
  Every directory in list should contain subdirectory created no earlier than 2 days ago with size greater than 500KB
  and the name consisting of numbers and the underscore between them.
 [file tail $argv0] -H ops-backuprestore-db-m1.vega.ironport.com -d '/mnt/vega_db_backups/prod-wbrsrule-db-s2-1/mysql/full-backups' -t '.* \\d+_\\d+ size min 500k' -t '.* \\d+_\\d+ mtime min 2d' -c 
  The same checks but output in cacti format.
"

### parse CLI part
# print USAGE if run without CLI args
if {$argc == 0} {
	puts $USAGE
	exit $EXIT_UNKNOWN
}
# parse CLI params
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit $EXIT_UNKNOWN
}
# switches
::opscfg::getswitchopt argv [list "-l" "--latest"] ::script_parameters::latest
::opscfg::getswitchopt argv [list "-v" "--verbose"] ::script_parameters::verbose
::opscfg::getswitchopt argv [list "-c" "--cacti"] ::script_parameters::cacti_output
::opscfg::getswitchopt argv [list "-F" "--freebsd"] ::script_parameters::freebsd
::opscfg::getswitchopt argv [list "-r" "--reducenames"] ::script_parameters::reduce_names
::opscfg::getswitchopt argv [list "-T" "--trim-common"] ::script_parameters::trim_common
::opscfg::getswitchopt argv [list "-A" "--match-all"] ::script_parameters::match_all
# arguments
::opscfg::getopt argv [list "-R" "--retry-count"] ::script_parameters::retry_count
::opscfg::getopt argv [list "-H" "--host"] ::script_parameters::host
::opscfg::getopt argv [list "-u" "--username"] ::script_parameters::username
if {[::opscfg::getopt argv [list "-p" "--password"] ::script_parameters::password ""]} {
	if {[catch {package require Expect} result]} {
		puts stderr "For using ssh password authentication you should install expect package"
		exit $EXIT_UNKNOWN
	}
	if [file readable $::script_parameters::password] {
		# this is a file with password
		set fileId [open $::script_parameters::password r]
		set ::script_parameters::password [gets $fileId]
		close $fileId
	}
}
while {[::opscfg::getopt argv [list "-t" "--thresholds"] threshold]} {
	# threshold specification: "directory_regexp subdirectory_regexp check_type min/max/equal/nonequal error_value [warning_value]"
	set threshold_list [split $threshold]
	if {[llength $threshold_list] < 5} {
		puts stderr "Invalid threshold specification \"$threshold\""
		puts $USAGE
		exit $EXIT_UNKNOWN
	}
	# check check_type
	switch -exact -- [lindex $threshold_list 2] {
		"mtime" {
			set counter_type "mtime"
		}
		default {
			set counter_type "size"
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
	if {$counter_type == "mtime"} {
		# expand and calculate value
		set counter_error [expr [clock seconds] - [::opscfg::expandtime $counter_error]]
		set counter_warning [expr [clock seconds] - [::opscfg::expandtime $counter_warning]]
	} else {
		# expand value
		set counter_error [::opscfg::expandsize $counter_error]
		set counter_warning [::opscfg::expandsize $counter_warning]
	}
	# add threshold to list
	lappend new_thresholds [list [lindex $threshold_list 0] [lindex $threshold_list 1] $counter_type $check_type $counter_error $counter_warning]
}
if [info exists new_thresholds] {
	set ::script_parameters::thresholds $new_thresholds
}
while {[::opscfg::getopt argv [list "-d" "--directory"] directory]} {
	lappend ::script_parameters::directory $directory
}
# check that all params are present
foreach v [info vars ::script_parameters::*] {
	# password can be empty
	if {([set [set v]] == "") && ([set v] != "::script_parameters::password")} {
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
### main part
# create ssh client instance
package require opsssh
if {$::script_parameters::password != ""} {
	set ssh_client [::opsssh::openssh -retry $::script_parameters::retry_count -host $::script_parameters::host -username $::script_parameters::username -password $::script_parameters::password]
} else {
	set ssh_client [::opsssh::openssh -retry $::script_parameters::retry_count -host $::script_parameters::host -username $::script_parameters::username]
}
# create command for ssh
set ssh_command "date +%s"
foreach directory $::script_parameters::directory {
	if $::script_parameters::freebsd {
		append ssh_command "; du -k -d 1 $directory 2> /dev/null | grep -vE '[file tail $directory]\$'"
		append ssh_command "; ls -alTt $directory | grep -E '^d'"
	} else {
		append ssh_command "; du -k --max-depth=1 $directory 2> /dev/null | grep -vE '[file tail $directory]\$'"
		append ssh_command "; ls -alt --time-style '+%b %d %H:%M:%S %Y' $directory | grep -E '^d'"
	}
}
if {$::script_parameters::verbose} {
	puts stderr "Run command on remote server:"
	puts stderr "\t$ssh_command"
}
# execute ssh command
if [catch {::opsssh::ssh -sshId $ssh_client -- $ssh_command} ssh_output_list] {
	puts stderr "SSH connection error"
	global errorCode
	puts stderr "ssh exit with code $errorCode"
	puts stderr "ssh output: $ssh_output_list"
	exit $EXIT_ERROR
}
# parse output and create array of arrays directory_array with following structure:
# {directory_path 
#     {subdirectory
#         {size size_in_bytes
#          mtime mtime_in_unixtime}
#      subdirectory2
#         {...}
#      ...}
#  directory_path2
#      {...}
#  ...}
if {$::script_parameters::verbose} {
	puts stderr "Processed directories:"
}
# dirty fix - add directory when script do not have access to du subdirs
set current_dir [lindex $::script_parameters::directory  0]
foreach str $ssh_output_list {
	switch -regexp -- $str {
		{^\d+$} {
			# set current datetime from first line of ssh output
			set current_datetime $str
		}
		{^\d+\s+.*/.*$} {
			# df output - split it to size and directory path
			regexp {^(\d+)\s+(.*)$} $str match size path
			if {$::script_parameters::verbose} {
				puts stderr "\t Added $path with size [expr $size * 1024]"
			}
			if {[array names directory_array -exact [file dirname $path]] != {}} {
				# this path present in array
				lappend directory_array([file dirname $path]) [file tail $path] [list "size" [expr $size * 1024]]
			} else {
				# this path does not present - create array entry
				set directory_array([file dirname $path]) [list [file tail $path] [list "size" [expr $size * 1024]]]
			}
			set current_dir [file dirname $path]
		}
		{^d[r-][w-][x-].*\s+\.+$} {
			# ls current or parent directory
			continue
		}
		{^d[r-][w-][x-]} {
			# ls directory attributes output - split it. example string:
			# drwxr-xr-x  14 traffic_corpus  traffic_corpus  4096 Dec  4 09:15:34 2012 2012
			if [regexp -expanded {^d[rwx-]{9}\s+\d+\s+\w+\s+\w+\s+\d+\s+(\w+\s+\d+\s+\d+:\d+:\d+\s+\d+)\s+(.*?)$} $str match string_datetime subdirectory] {
				# check directory by include/exclude regexp
				if {$::script_parameters::verbose} {
					puts stderr "\t Added directory [file join $current_dir $subdirectory] with mtime $string_datetime"
				}
				# convert string from ls to unixtime
				set mtime [clock scan $string_datetime]
				# check if current directory present in the array
				if {[array names directory_array -exact $current_dir] != {}} {
					# this directory in array - add mtime
					array unset subdirectory_array
					array set subdirectory_array $directory_array($current_dir)
					lappend subdirectory_array($subdirectory) "mtime" $mtime
					if {[lsearch -exact $subdirectory_array($subdirectory) "size"] == -1} {
						# size is absent - set it to 0
						lappend subdirectory_array($subdirectory) "size" 0
					}
					set directory_array($current_dir) [array get subdirectory_array]
				} else {
					# this directory absent in array
					set directory_array($current_dir) [list $subdirectory [list "mtime" $mtime "size" 0]]
				}
			} else {
				# can not parse ls string - skip it
			}
		}
	}
}
if {$::script_parameters::verbose} {
	puts stderr "Collected data:"
	puts stderr "\t [array get directory_array]"
	puts stderr "Collected time: $current_datetime"
}
# array with needed data was created - check data
# format matched array
array unset matched_array
set exit_code $EXIT_OK
set exit_message "OK"
# convert thresholds list to thresholds array of lists with check_type
# as keys
foreach threshold $::script_parameters::thresholds {
	lappend thresholds_array([lindex $threshold 2]) $threshold
}
array set matched_data_array [array get directory_array]
foreach threshold_types [array names thresholds_array] {
	if {$::script_parameters::verbose} {
		puts stderr "Processing threshold type: $threshold_types"
	}
	# leave only matched directories
	array unset directory_array
	array set directory_array [array get matched_data_array]
	array unset matched_data_array
	if {$::script_parameters::verbose} {
		puts stderr "Processing data:" ; puts stderr [array get directory_array]
	}
	foreach threshold $thresholds_array($threshold_types) {
		# in threshold list item 0 - directory regexp, 1 - subdirectory regexp,
		# 2 - check type
		# get matched directories
		set matched_directories [array names directory_array -regexp [lindex $threshold 0]]
		if {$matched_directories == {}} {
			set exit_code $EXIT_ERROR
			set exit_message "Threshold \"$threshold\" did not find in the directories"
		}
		foreach directory $matched_directories {
			array unset subdirectory_array
			array set subdirectory_array $directory_array($directory)
			# get matched subdirectories
			set matched_subdirectories [array names subdirectory_array -regexp [lindex $threshold 1]]
			if {$matched_subdirectories == {}} {
				set exit_code $EXIT_ERROR
				set exit_message "Threshold \"$threshold\" did not find in the subdirectories"
				continue
			}
			if $::script_parameters::latest {
				# leave only latest subdirectory
				set max_mtime 0
				set latest_subdirectory ""
				foreach subdirectory $matched_subdirectories {
					array unset subdir_array
					array set subdir_array $subdirectory_array($subdirectory)
					if {$subdir_array(mtime) > $max_mtime} {
						set max_mtime $subdir_array(mtime)
						set latest_subdirectory $subdirectory
					}
				}
				set matched_subdirectories [list $latest_subdirectory]
			}
			set matched_subdirectory 0
			set checked_subdirectory ""
			foreach subdirectory $matched_subdirectories {
				array unset subdir_array
				array set subdir_array $subdirectory_array($subdirectory)
				set matched_array_key [file join $directory $subdirectory]
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
				if {(![expr $subdir_array([lindex $threshold 2]) $comparison [lindex $threshold 4]]) && \
				      (![expr $subdir_array([lindex $threshold 2]) $comparison [lindex $threshold 5]])} {
					# needed value
					if {[array names matched_array -exact $matched_array_key] == {}} {
						# add new item to matched_array
						set matched_array($matched_array_key) $subdirectory_array($subdirectory)
					}
					set matched_subdirectory 1
					lappend matched_data_array($directory) $subdirectory $subdirectory_array($subdirectory)
				} else {
					set checked_subdirectory $subdirectory
				}
			}
			if {!$matched_subdirectory} {
				# add to matched_array
				lappend matched_data_array($directory) $checked_subdirectory $subdirectory_array($checked_subdirectory)
				array unset subdir_array
				array set subdir_array $subdirectory_array($checked_subdirectory)
				set matched_array_key [file join $directory $checked_subdirectory]
				if {[array names matched_array -exact $matched_array_key] == {}} {
					# add new item to matched_array
					set matched_array($matched_array_key) $subdirectory_array($checked_subdirectory)
				}
				# check error or warning
				if [expr $subdir_array([lindex $threshold 2]) $comparison [lindex $threshold 4]] {
					# error value
					if {$exit_code != $EXIT_ERROR} {
						set exit_code $EXIT_ERROR
						if {[lindex $threshold 2] == "mtime"} {
							# convert unix time to text
							set exit_message "ERROR - directory [file join $directory $checked_subdirectory] mtime equal to [clock format $subdir_array(mtime) -format {%Y-%m-%dT%H:%M:%S}] but [lindex $threshold 3] is [clock format [lindex $threshold 4] -format {%Y-%m-%dT%H:%M:%S}]"
						} else {
							set exit_message "ERROR - directory [file join $directory $checked_subdirectory] size equal to $subdir_array(size) but [lindex $threshold 3] is [lindex $threshold 4]"
						}
					}
				} else {
					# warning value
					if {($exit_code != $EXIT_ERROR) && ($exit_code != $EXIT_WARNING)} {
						set exit_code $EXIT_WARNING
						if {[lindex $threshold 2] == "mtime"} {
							# convert unix time to text
							set exit_message "WARNING - directory [file join $directory $checked_subdirectory] mtime equal to [clock format $subdir_array(mtime) -format {%Y-%m-%dT%H:%M:%S}] but [lindex $threshold 3] is [clock format [lindex $threshold 4] -format {%Y-%m-%dT%H:%M:%S}]"
						} else {
							set exit_message "WARNING - directory [file join $directory $checked_subdirectory] size equal to $subdir_array(size) but [lindex $threshold 3] is [lindex $threshold 4]"
						}
					}
				}
			}
		}
	}
	if {!$::script_parameters::match_all} {
		# keep all data
		array unset matched_data_array
		array set matched_data_array [array get directory_array]
	}
}
# convert matched_array to result_array
array unset result_array
if {$::script_parameters::trim_common} {
	# find common part of path
	set common_part ""
	set path_list [array names matched_array]
	if {$path_list != {}} {
		set path_list_length [llength $path_list]
		foreach path_part [file split [lindex $path_list 0]] {
			if {[llength [lsearch -all -glob $path_list "[file join $common_part $path_part]*"]] == $path_list_length} {
				# this path part contains in all directories
				set common_part [file join $common_part $path_part]
			} else {
				# this path part missed in some directories
				break
			}
		}
	}
	if {$common_part != ""} {
		set common_part "[set common_part]/"
	}
	if {$::script_parameters::verbose} {
		puts stderr "Trimming common path part: $common_part"
	}
}
set common_part_length [string length $common_part]
foreach directory [array names matched_array] {
	if {$::script_parameters::trim_common} {
		set result_directory [string range $directory $common_part_length end]
	} else {
		set result_directory $directory
	}
	array unset subdir_array
	array set subdir_array $matched_array($directory)
	set result_array_key "[set result_directory]_size"
	set result_array($result_array_key) [list $subdir_array(size) "$result_array_key = $subdir_array(size)"]
	set result_array_key "[set result_directory]_mtime"
	set result_array($result_array_key) [list $subdir_array(mtime) "$result_array_key = [clock format $subdir_array(mtime) -format {%Y-%m-%dT%H:%M:%S}]"]
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
