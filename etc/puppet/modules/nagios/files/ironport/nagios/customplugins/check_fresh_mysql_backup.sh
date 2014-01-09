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
# MONOPS-396 - check_fresh_mysql_backup.sh check that backup server
# contains fresh backup of database.
#
# This scripts runs check_remote_directories.sh script with caching
# and return data in nagios format with perfdata.
#
# Return codes and their meaning:
#    Nagios:
#           0 (ok)
#           2 (critical) - when specified directory does not contain
#                          matched subdirectories or ssh can not
#                          connect to remote host
#           3 (unknown) - when specified bad CLI options or no data returned
#
# Maksym Tiurin (mtiurin@cisco.com) 09/12/2013
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
	array set collocation_backup_path {vega vega_db_backups1 sv4 sv4_db_backups}
	variable backup_host {ops-backuprestore-db-m1.[set ::script_parameters::collocation].ironport.com}
	variable collocation "vega"
	variable host ""
	variable server ""
	variable backup_path {/mnt/[set ::script_parameters::collocation_backup_path([set ::script_parameters::collocation])]/[set ::script_parameters::server]/mysql/full-backups}
	variable critical_age "2d"
	variable critical_size "512k"
	variable verbose 0
}


set USAGE "
USAGE:
	[file tail $argv0] \[OPTIONS\]

Check that backup server contains fresh backup for specified product.

Options
	-h/--help          Show this help screen
	-B/--backup-host   Backup storage host (default $::script_parameters::backup_host)
	-H/--host          FQDN of database host (required)
	-c/--collocation   Collocation of database host (default second part of FQDN)
	-s/--server        Server name (default first part of FQDN)
	-P/--backup-path   Path to backups (default $::script_parameters::backup_path)
	-A/--critical-age  Critical age of backup (default $::script_parameters::critical_age)
	-S/--critical-size Critical size of backup (default $::script_parameters::critical_size)
	-v/--verbose       Turn [::opscfg::bool2text [expr ! $::script_parameters::verbose]] verbose mode (default [::opscfg::bool2text $::script_parameters::verbose])
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
::opscfg::getswitchopt argv [list "-v" "--verbose"] ::script_parameters::verbose
# arguments
::opscfg::getopt argv [list "-P" "--backup-path"] ::script_parameters::backup_path
if [::opscfg::getopt argv [list "-H" "--host"] ::script_parameters::host] {
	# get collocation from host
	set ::script_parameters::collocation [lindex [split $::script_parameters::host {.}] 1]
        # SV4 is miscofigured for DH. Should be SV4 instead of SV2. If no direct specification substitude with SV4
        if {$::script_parameters::collocation == "sv2"} {
            set ::script_parameters::collocation "sv4"
        }
        # Same dirty hack for las1
        if {$::script_parameters::collocation == "las1"} {
            set ::script_parameters::collocation "vega"
        }
	# get server from host
	set ::script_parameters::server [lindex [split $::script_parameters::host {.}] 0]
}
::opscfg::getopt argv [list "-c" "--collocation"] ::script_parameters::collocation
::opscfg::getopt argv [list "-s" "--server"] ::script_parameters::server
if ![::opscfg::getopt argv [list "-B" "--backup-host"] ::script_parameters::backup_host] {
	# perform variable substitutions in backup host
	set ::script_parameters::backup_host [subst -nobackslashes $::script_parameters::backup_host]
}
# perform variable substitutions in backup path
set ::script_parameters::backup_path [subst -nobackslashes $::script_parameters::backup_path]
::opscfg::getopt argv [list "-A" "--critical-age"] ::script_parameters::critical_age
::opscfg::getopt argv [list "-S" "--critical-size"] ::script_parameters::critical_size
# check that all params are present
foreach v [info vars ::script_parameters::*] {
	if {![array exists [set v]] && ([set [set v]] == "")} {
		puts stderr "parameter [namespace tail $v] value should be set"
		exit $EXIT_UNKNOWN
	}
}
if {$::script_parameters::verbose} {
	# print script parameter variables with value
	puts stderr "Script parameters:"
	foreach v [info vars ::script_parameters::*] {
		if [array exists [set v]] {
			puts stderr "\t[namespace tail $v] = [array get [set v]]"
		} else {
			puts stderr "\t[namespace tail $v] = [set [set v]]"
		}
	}
}
### main part
# create command (caching part)
set check_command [list [file join $script_path "caching_timeout.sh"] "-f"]
lappend check_command [file join "/tmp" ".nagios.[file tail $argv0].[set ::script_parameters::host].cache"]
lappend check_command "-k" "0" "-F" "30m" "--"
# create command (main part)
lappend check_command [file join $script_path "check_remote_directories.sh"]
lappend check_command "-H" $::script_parameters::backup_host
lappend check_command "-d" $::script_parameters::backup_path
lappend check_command "-t" ".* \\d+_\\d+ size min $::script_parameters::critical_size"
lappend check_command "-t" ".* \\d+_\\d+ mtime min $::script_parameters::critical_age"
lappend check_command "--match-all"
if {$::script_parameters::verbose} {
	puts stderr "Command to execute: $check_command"
} else {
	lappend check_command "2>" "/dev/null"
}
set status [catch {eval exec [lrange $check_command 0 end]} output]
if {$status == 0} {
	# script exited normally (exit status 0) and wrote nothing to stderr"
	puts $output
	exit $EXIT_OK
} elseif {$::errorCode eq "NONE"} {
	# "script exited normally (exit status 0) but wrote something to stderr"
	puts $output
	exit $EXIT_OK
} elseif {[lindex $::errorCode 0] eq "CHILDSTATUS"} {
	# remove 'child process exited abnormally' string from output
	regsub -lineanchor -- "\\n^child process exited abnormally$" $output {} res
	puts $res
	exit [lindex $::errorCode end]
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
