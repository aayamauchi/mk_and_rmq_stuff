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
# Run nagios or cacti check scripts with timeouts
#
# This script runs specified nagios or cacti check script with
# timeouts. Check scrips writes data to cache file.
#
# Algorithm:
# 1) read cache file content and define exit code
# 2) if cache-timeout value not equal to 0
#     check mtime of cache file and when cache file not older than
#     timeout and not empty - return value from cache and exit
# 3) check kill-timeout value
#    a) not equal to 0
#       run specified check script in background with parameters and
#       self-kill when timeout is over
#    b) equal to 0
#       run specified check script in background with parameters
# 4) run event handler which returns data end exit code from cache
#    file when response timeout is over
# 5) run event handlers which checks cache file every second and when
#    this file is not empty read file content, define exit code and
#    return data and exit code
# 6) run event loop
#
# Maksym Tiurin (mtiurin@cisco.com) 06/14/2013
######################################################################

# add path to shared library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path "lib"]

# load module which provides exit codes and functions for format output
package require monoutput
# import CLI & config parser
package require opscfg 1.1
# load module to work with ssh
package require opsssh

# default values
namespace eval script_parameters {
	variable verbose 0
	# maximum timeout in seconds when script should return exit code
	variable response_timeout 35
	# maximum timeout in seconds for check running
	variable kill_timeout 295
	# file for check result
	variable cache_file ""
	# consider unknown result as critical
	variable unknown_is_critical 0
	# check script to execute
	variable check_script {}
	# check script is a cacti check
	variable cacti_output 0
	# maximum timeout when cached results are valid and check script run not needed
	variable fresh_cache_timeout 0
	# remote server hostname for remote command execution
	variable remote_server_host ""
	# remote server ssh port
	variable remote_server_port 22
	# ssh key file
	variable remote_server_key ""
	# username for remote server connecion
	variable remote_server_username "nagios"
	# password for remote server connecion
	variable remote_server_password $::opsssh::null_password ; # this random string means 'without password'
	# tries to execute remote command
	variable remote_server_retry 2
}

set USAGE "
USAGE:
        [file tail $argv0] \[OPTIONS\] script_to_execute script parameters
Run specified nagios script

Options:
	-h/--help                Show this help screen
	-v/--verbose             Turn [::opscfg::bool2text [expr ! $::script_parameters::verbose]] verbose mode (default [::opscfg::bool2text $::script_parameters::verbose])
	-C/--unknown-is-critical Turn [::opscfg::bool2text [expr ! $::script_parameters::unknown_is_critical]] considering unknown messages as critical (default [::opscfg::bool2text $::script_parameters::unknown_is_critical])
	-f/--cache-file          Full path to the check results cache file
	-r/--response-timeout    Maximum timeout in seconds when script should return exit code (default $::script_parameters::response_timeout)
	                         Suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
	-k/--kill-timeout        Maximum timeout in seconds for check running (time between check runs) (default $::script_parameters::kill_timeout)
	                         Setting this timeout to 0 disables it altogether.
	                         This feature supported for local commands only.
	                         Suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
	-F/--fresh-cache-timeout Maximum timeout in seconds when cached results are fresh, valid and check script run not needed (default: $::script_parameters::fresh_cache_timeout)
	                         Setting this timeout to 0 disables it altogether.
	                         Suffix may be 's' for seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days.
	-c/--cacti               Turn [::opscfg::bool2text [expr ! $::script_parameters::cacti_output]] cacti type output (default [::opscfg::bool2text $::script_parameters::cacti_output])
	-H/--host                Hostname for ssh connect (default: execute locally)
	-P/--port                Remote host ssh port (default: $::script_parameters::remote_server_port)
	-K/--key                 Path to ssh key (default: use ssh key auto-detection)
	-u/--username            Ssh username (default: $::script_parameters::remote_server_username)
	-p/--password            Ssh password (default: unspecified, use ssh key instead of password)
	-R/--retry               Retry count to execute remote command (default: $::script_parameters::remote_server_retry)
	--                       End of options flag. After this flag all options are script_to_execute with parameters
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
# check end of options flag
set eoo_idx [lsearch -exact $argv "--"]
if {$eoo_idx != -1} {
	# argv contains end of options flag
	set ::script_parameters::check_script [lrange $argv [expr $eoo_idx + 1] end]
	set argv [lrange $argv 0 [expr $eoo_idx - 1]]
}
::opscfg::getswitchopt argv [list "-v" "--verbose"] ::script_parameters::verbose
::opscfg::getswitchopt argv [list "-C" "--unknown-is-critical"] ::script_parameters::unknown_is_critical
::opscfg::getswitchopt argv [list "-c" "--cacti"] ::script_parameters::cacti_output
::opscfg::getopt argv [list "-f" "--cache-file"] ::script_parameters::cache_file
::opscfg::getopt argv [list "-r" "--response-timeout"] ::script_parameters::response_timeout
::opscfg::getopt argv [list "-k" "--kill-timeout"] ::script_parameters::kill_timeout
::opscfg::getopt argv [list "-F" "--fresh-cache-timeout"] ::script_parameters::fresh_cache_timeout
# expand time values
foreach var {response_timeout kill_timeout fresh_cache_timeout} {
	if [catch {::opscfg::expandtime [set ::script_parameters::[set var]]} ::script_parameters::[set var]] {
		puts stderr "Bad $var value specified"
		exit $EXIT_UNKNOWN
	}
}
::opscfg::getopt argv [list "-H" "--host"] ::script_parameters::remote_server_host
::opscfg::getopt argv [list "-P" "--port"] ::script_parameters::remote_server_port
::opscfg::getopt argv [list "-K" "--key"] ::script_parameters::remote_server_key
::opscfg::getopt argv [list "-u" "--username"] ::script_parameters::remote_server_username
::opscfg::getopt argv [list "-p" "--password"] ::script_parameters::remote_server_password
::opscfg::getopt argv [list "-R" "--retry"] ::script_parameters::remote_server_retry
if {$eoo_idx == -1} {
	# argv contains script with parameters
	set ::script_parameters::check_script $argv
}
# kill timeout should be more or equal to response timeout
if {($::script_parameters::kill_timeout) && ($::script_parameters::kill_timeout < $::script_parameters::response_timeout)} {
	puts stderr "kill-timeout value should be more than response-timeout"
	exit $EXIT_UNKNOWN
}
# check that all params are present
foreach v [info vars ::script_parameters::*] {
	if {([set [set v]] == "") && (![string match {::script_parameters::remote_server_*} [set v]])} {
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
# main part
# namespace with check results
namespace eval check_results {
	variable text_result ""
	variable exit_code $EXIT_UNKNOWN
}
# check content of text result and set appropriate exit code
proc set_exit_code {} {
	variable ::check_results::exit_code
	variable ::check_results::text_result
	variable ::script_parameters::cacti_output
	variable ::script_parameters::unknown_is_critical
	global EXIT_OK
	global EXIT_WARNING
	global EXIT_ERROR
	global EXIT_UNKNOWN
	if {$::script_parameters::cacti_output} {
		# check using cacti regexp
		if [regexp -expanded {^\w+:\d+(\.\d*)?} $::check_results::text_result] {
			# good result
			set ::check_results::exit_code $EXIT_OK
		} else {
			set ::check_results::exit_code $EXIT_ERROR
		}
	} else {
		# check using nagios regexps
		switch -regexp -- $::check_results::text_result {
			{^[Oo][Kk]} {
				set ::check_results::exit_code $EXIT_OK
			}
			{^[Ww][Aa][Rr][Nn]} {
				set ::check_results::exit_code $EXIT_WARNING
			}
			{^([Ee][Rr][Rr])|([Cc][Rr][Ii][Tt])} {
				set ::check_results::exit_code $EXIT_ERROR
			}
			default {
				if {$::script_parameters::unknown_is_critical} {
					set ::check_results::exit_code $EXIT_ERROR
				} else {
					set ::check_results::exit_code $EXIT_UNKNOWN
				}
			}
		}
	}
}
# check cache file
if {([file exists $::script_parameters::cache_file]) && (![file writable $::script_parameters::cache_file])} {
		if {$::script_parameters::cacti_output} {
			puts stderr "Unable to write to cache file $::script_parameters::cache_file"
		} else {
			puts "Unable to write to cache file $::script_parameters::cache_file"
		}
		exit $EXIT_ERROR
	}
if [file readable $::script_parameters::cache_file] {
	set fileId [open $::script_parameters::cache_file r]
	set ::check_results::text_result [read -nonewline $fileId]
	close $fileId
	set_exit_code
	# check cache file mtime
	if {($::script_parameters::fresh_cache_timeout != 0) && ($::check_results::text_result != "")} {
		if {[expr {[clock seconds] - [file mtime $::script_parameters::cache_file]}] < $::script_parameters::fresh_cache_timeout} {
			# cache file fresh and not empty - just return results
			puts $::check_results::text_result
			exit $::check_results::exit_code
		}
	}
}
if {$::script_parameters::remote_server_host != ""} {
	# remote command execution using ssh
	# create client
	if {$::script_parameters::remote_server_key != ""} {
		set sshId [::opsssh::openssh -retry $::script_parameters::remote_server_retry -host $::script_parameters::remote_server_host \
		             -port $::script_parameters::remote_server_port -username $::script_parameters::remote_server_username \
		             -password $::script_parameters::remote_server_password -key $::script_parameters::remote_server_key]
	} else {
		set sshId [::opsssh::openssh -retry $::script_parameters::remote_server_retry -host $::script_parameters::remote_server_host \
		             -port $::script_parameters::remote_server_port -username $::script_parameters::remote_server_username \
		             -password $::script_parameters::remote_server_password]
	}
}
# run check script in background
if {($::script_parameters::kill_timeout) && (![info exists sshId])} {
	# run check script with autokill (local mode)
	set script_cmd_line ""
	foreach script $::script_parameters::check_script {
		if [regexp -expanded {.+[^\\]\s.+} $script] {
			# contain space - add quotes
			append script_cmd_line " " \" $script \"
		} else {
			append script_cmd_line " " $script
		}
	}
	# make command list to execute
	lappend cmd_list bash "-c"
	lappend cmd_list "($script_cmd_line > \"$::script_parameters::cache_file\") & export pid=\$! ; (sleep $::script_parameters::kill_timeout ; kill -HUP \$pid) & export watcher=\$! ; wait \$pid && pkill -HUP -P \$watcher"
	lappend cmd_list ">&" "/dev/null"
	lappend cmd_list "&"
} else {
	# run script without autokill
	if ![info exists sshId] {
		set cmd_list $::script_parameters::check_script
		lappend cmd_list ">" $::script_parameters::cache_file
		lappend cmd_list "2>" "/dev/null"
		lappend cmd_list "&"
	} else {
		set cmd_list {}
		foreach script $::script_parameters::check_script {
			if [regexp -expanded {.+[^\\]\s.+} $script] {
				# contain space - add quotes
				lappend cmd_list \"$script\"
			} else {
				lappend cmd_list $script
			}
		}
		lappend cmd_list "2>" "/dev/null"
	}
}
# execute command
if {$::script_parameters::verbose} {
	puts stderr "Run command in background:"
	puts stderr "\t[join $cmd_list { }]"
}
if ![info exists sshId] {
	catch {eval exec [lrange $cmd_list 0 end]} result
} else {
	# run command using ssh
	if {$::script_parameters::remote_server_password == $::opsssh::null_password} {
		# without password & expect
		proc ssh_handler {sshId cmd_list} {
			variable ::script_parameters::cache_file
			catch {::opsssh::ssh -sshId $sshId -- [join $cmd_list " "] ">" $::script_parameters::cache_file} result
		}
	} else {
		# using password & expect
		proc ssh_handler {sshId cmd_list} {
			variable ::script_parameters::cache_file
			set fileId [open $::script_parameters::cache_file w]
			flush $fileId
			if ![catch {::opsssh::ssh -sshId $sshId -- [join $cmd_list " "]} result] {
				foreach line $result {
					if {$line != ""} {
						puts $fileId $line
					}
				}
			}
			close $fileId
		}
	}
	after 1 ssh_handler $sshId [list $cmd_list]
}
# force set 0666 permissions for cache file
catch {file attributes $::script_parameters::cache_file -permissions "rw-rw-rw-"} 
# file handler for check file
proc cache_file_handler {} {
	variable ::check_results::exit_code
	variable ::check_results::text_result
	variable ::script_parameters::cache_file
	global done
	if [file size $::script_parameters::cache_file] {
		set fileId [open $::script_parameters::cache_file r]
		set ::check_results::text_result [read -nonewline $fileId]
		catch {close $fileId}
		set_exit_code
		set done 1
		puts $::check_results::text_result
		exit $::check_results::exit_code
	}
}
# timeout handler
proc timeout_handler {} {
	variable ::check_results::exit_code
	variable ::check_results::text_result
	global done
	set_exit_code
	set done 1
	# show message and exit
	puts $::check_results::text_result
	exit $::check_results::exit_code
}
# register timeout handler
after [expr $::script_parameters::response_timeout * 1000] timeout_handler
if [file readable $::script_parameters::cache_file] {
	# register events for cache file
	for {set i 0} {$i < $::script_parameters::response_timeout} {incr i} {
		# check file every second during response time
		after [expr $i*1000+1] cache_file_handler
	}
}
# run event loop
vwait done

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
