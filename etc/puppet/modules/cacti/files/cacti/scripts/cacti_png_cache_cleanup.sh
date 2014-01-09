#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# specify tcl prefer version \
TCL=tclsh
# prefer versions 8.2 -> 8.3 -> 8.4 -> 8.6 -> 8.5 \
for v in 8.2 8.3 8.4 8.6 8.5; do type tclsh$v >/dev/null 2>&1 && TCL=tclsh$v; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

######################################################################
# MONOPS-1397 - script for remove old PNG files from cacti boost cache
# directory
#
# This scripts get from cacti database path to boost cache directory,
# check mtime of png files in this directory and delete old png files.
# Can be used as cron job.
#
# Return codes and their meaning:
#           0 (ok)
#           1 - CLI parameters error
#           2 - MySQL connection error
#
# Maksym Tiurin (mtiurin@cisco.com) 03/22/2013
######################################################################

# add path to shared library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path "lib"]
# import CLI & config parser
package require opscfg

# default values
namespace eval script_parameters {
	variable verbose 0
	variable expiration_time 5400
	variable cleanup_files "*.png"
	variable cacti_DB_config "/usr/share/cacti/include/config.php"
	variable DB_host ""
	variable DB_database ""
	variable DB_username ""
	variable DB_password ""
	variable DB_port 3306
	variable log_file "/dev/null"
	variable dry_run 0
}

set USAGE "
USAGE:
	[file tail $argv0] \[OPTIONS\]

Remove old png files from boost png cache directory.

Options
	-h/--help         Show this help screen
	-v/--verbose      Verbose mode (default: [::opscfg::bool2text $::script_parameters::verbose])
	-c/--dbconfig     Path to cacti database configuration file (default: $::script_parameters::cacti_DB_config)
	-d/--dbhost       MySQL host where cacti database is located (default from cacti database configuration file)
	-b/--db           Cacti database name (default from cacti database configuration file)
	-u/--dbuser       MySQL username (default from cacti database configuration file)
	-p/--dbpass       MySQL password (default from cacti database configuration file)
	-P/--dbport       MySQL server port (default from cacti database configuration file)
	-t/--time         PNG files expiration time in seconds (default $::script_parameters::expiration_time)
	                  Suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
	-l/--log          Log file (default: $::script_parameters::log_file)
	--dry-run         Do not delete files (default: [::opscfg::bool2text $::script_parameters::dry_run])
"

# parse CLI options
if {[::opscfg::getopt argv [list "-h" "--help"]]} {
	puts $USAGE
	exit 0
}
if [::opscfg::getopt argv [list "-v" "--verbose"]] {
	set ::script_parameters::verbose 1
}
::opscfg::getopt argv [list "-c" "--dbconfig"] ::script_parameters::cacti_DB_config
::opscfg::getopt argv [list "-d" "--dbhost"] ::script_parameters::DB_host
::opscfg::getopt argv [list "-b" "--db"] ::script_parameters::DB_database
::opscfg::getopt argv [list "-u" "--dbuser"] ::script_parameters::DB_username
::opscfg::getopt argv [list "-p" "--dbpass"] ::script_parameters::DB_password
::opscfg::getopt argv [list "-P" "--dbport"] ::script_parameters::DB_port
::opscfg::getopt argv [list "-l" "--log"] ::script_parameters::log_file
::opscfg::getopt argv [list "-t" "--time"] ::script_parameters::expiration_time
if [::opscfg::getopt argv "--dry-run"] {
	set ::script_parameters::dry_run 1
}
# check expiration time
if [catch {::opscfg::expandtime $::script_parameters::expiration_time} ::script_parameters::expiration_time] {
	puts stderr "Bad time value specified"
	exit 1
}
# parse cacti DB config
if [catch {open $::script_parameters::cacti_DB_config r} fileId] {
	puts stderr "Unable to open Cacti DB configuration file $::script_parameters::cacti_DB_config"
	global errorCode
	puts stderr "exit code $errorCode"
	puts stderr "output: $fileId"
	exit 1
}
set cacti_db_config [read $fileId]
close $fileId
foreach {script_param config_param} {DB_host database_hostname DB_database database_default DB_username database_username DB_password database_password DB_port database_port} {
	if {[set ::script_parameters::[set script_param]] == ""} {
		regexp "\\$$config_param\\s+=\\s+\"(\[^\\n\]*)\";" $cacti_db_config res ::script_parameters::[set script_param]
	}
}
# check that all params are present
foreach v [info vars ::script_parameters::*] {
	if {[set [set v]] == ""} {
		puts stderr "parameter [namespace tail $v] value should be set"
		exit 1
	}
}
if {$::script_parameters::verbose} {
	# print script parameter variables with value
	puts stderr "Script parameters:"
	foreach v [info vars ::script_parameters::*] {
		puts stderr "\t[namespace tail $v] = [set [set v]]"
	}
}
# import logger package
package require opslogger
# open script log
if [catch {::opslogger::openlog -appname "PNG_CACHE_CLEANUP" -- $::script_parameters::log_file} loggerId] {
	puts stderr "Unable to open log file $::script_parameters::log_file"
	global errorCode
	puts stderr "exit code $errorCode"
	puts stderr "output: $log_fileId"
	exit 1
}
# get boost_png_cache_directory value
package require opsdb
# run single queue without client creation
set sql "select value from settings where name='boost_png_cache_directory'"
if {$::script_parameters::verbose} {
	puts stderr "Execute mysql queue: $sql"
}
if [catch {::opsdb::mysql -retry 2 \
						 -command mysql \
						 -commandargs "-s" \
						 -host $::script_parameters::DB_host \
						 -port $::script_parameters::DB_port \
						 -username $::script_parameters::DB_username \
						 -password $::script_parameters::DB_password  \
						 -database $::script_parameters::DB_database -- $sql} mysql_output] {
	puts stderr "MySQL connection error"
	::opslogger::putslog -error -- $loggerId "MySQL connection error"
	global errorCode
	puts stderr "mysql exit with code $errorCode"
	puts stderr "mysql output: $mysql_output"
	exit 2
}
# make array from mysql output
if {[llength [lindex $mysql_output 0]] < 2} {
	puts stderr "Unable to find boost_png_cache_directory"
	::opslogger::putslog -error -- $loggerId "Unable to find boost_png_cache_directory"
	exit 2
}
array set mysql_array [lindex $mysql_output 0]
# find expired files
set expiration_time [expr [clock seconds] - $::script_parameters::expiration_time]
set deleted_files 0
set not_deleted_files 0
foreach filename [glob -nocomplain -types f [file join $mysql_array(value) $::script_parameters::cleanup_files]] {
	if {[file mtime $filename] < $expiration_time} {
		if {$::script_parameters::verbose} {
			puts -nonewline stderr "Removing $filename"
		}
		if [file writable $filename] {
			if {!$::script_parameters::dry_run} {
				file delete -force $filename
			}
			if {$::script_parameters::verbose} {
				::opslogger::putslog -debug -- $loggerId "$filename was deleted"
				puts stderr "\t DONE"
			}
			incr deleted_files
		} else {
			::opslogger::putslog -warning -- $loggerId "$filename was not deleted"
			if {$::script_parameters::verbose} {
				puts stderr "\t FAILED"
			}
			incr not_deleted_files
		}
	}
}
if {$::script_parameters::verbose} {
	puts stderr "$deleted_files files were deleted"
	puts stderr "$not_deleted_files files were unable to deleted"
}
::opslogger::putslog $loggerId "$deleted_files files were deleted"
::opslogger::putslog $loggerId "$not_deleted_files files were unable to deleted"
::opslogger::closelog $loggerId
exit 0
# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
