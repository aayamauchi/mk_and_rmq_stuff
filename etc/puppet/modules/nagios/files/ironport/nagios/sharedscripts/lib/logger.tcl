lappend auto_path [file dirname [info script]]

namespace eval ::opslogger {
	namespace export opslogger
	variable version 0.2
	variable logger_idx 0
	array set level {error 0 warning 1 info 2 debug 3}
}

package provide opslogger $::opslogger::version
# ::opslogger::openlog -- open log file
#
# Open log file specified by path.
#
# Arguments:
# ?-dateformat formatstring  - string with datetime format
#           specification for the clock format function
# ?-appname applicationname  - string with application name which
#           will be place in log records
# ?-verbosity string         - string with maximal verbosity level
#           one of debug/info/warning/error (default debug)
# ?--                        - flag for stop parsing arguments
# logfilename                - string with log file path
#
# Side Effects:
# Create new namespace opslogger::opslogN with log file settings
# variables.
# Open file descriptor for log file.
#
# Results:
# string with new namespace name or error when log can not be opened
# for appending
proc ::opslogger::openlog {args} {
	variable logger_idx
	incr logger_idx
	namespace eval ::opslogger::opslog[set logger_idx] {
		variable appname ""
		variable dateformat {%m/%d/%Y %I:%M:%S %p}
		variable logfileId ""
		variable verbosity $::opslogger::level(debug)
	}
	set args $args
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			{-dateformat} {
				set ::opslogger::opslog[set logger_idx]::dateformat [lindex $args 1]
				set args [lrange $args 2 end]
			}
			{-appname} {
				set ::opslogger::opslog[set logger_idx]::appname [lindex $args 1]
				set args [lrange $args 2 end]
			}
			{-verbosity} {
				if {[array names ::opslogger::level -exact [lindex $args 1]] != ""} {
					set ::opslogger::opslog[set logger_idx]::verbosity $::opslogger::level([lindex $args 1])
				}
				set args [lrange $args 2 end]
			}
		}
	}
	set ::opslogger::opslog[set logger_idx]::logfileId [open [lindex $args 0] a]
	return "opslog$logger_idx"
}
# ::opslogger::closelog -- close opened log file
#
# Close opened log file and delete appropriate namespace.
#
# Arguments:
# loggerId  - string with log namespace name
#
# Side Effects:
# Close file descriptor for log file.
# Delete appropriate log namespace opslogger::opslogN with log file
# settings variables.
#
# Results:
# 0 when function is worked successfully
# -1 when log namespace does not exists
proc ::opslogger::closelog {loggerId} {
	if [namespace exists ::opslogger::[set loggerId]] {
		variable ::opslogger::[set loggerId]::logfileId
		close $logfileId
		namespace delete ::opslogger::[set loggerId]
		return 0
	} else {
		return -1
	}
}
# ::opslogger::putslog -- put record to the log file
#
# Put formated record message to the log file.
#
# Arguments:
# ?-debug   - flag for set DEBUG log level
# ?-info    - flag for set INFO log level (default)
# ?-warning - flag to set WARNING log level
# ?-error   - flag to set ERROR log level
# ?--       - flag for stop parsing arguments
# logfileId - string with log namespace name
# message   - string with message for record to the log
#
# Side Effects:
# None.
#
# Results:
# 0 when function is worked successfully
# -1 when log namespace does not exists
proc ::opslogger::putslog {args} {
	set args $args
	set level "info"
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			{-debug} -
			{-info} -
			{-warning} -
			{-error} {
				set level [string trimleft $arg "-"]
				set args [lrange $args 1 end]
			}
		}
	}
	set loggerId [lindex $args 0]
	# check maximum verbosity
	variable ::opslogger::[set loggerId]::verbosity
	if {$::opslogger::level($level) <= $verbosity} {
		if [namespace exists ::opslogger::[set loggerId]] {
			variable ::opslogger::[set loggerId]::appname
			variable ::opslogger::[set loggerId]::dateformat
			variable ::opslogger::[set loggerId]::logfileId
			if {$appname != ""} {
				set msg "[clock format [clock seconds] -format $dateformat] - [set appname]: [string toupper [set level]]: [lrange [set args] 1 end]"
			} else {
				set msg "[clock format [clock seconds] -format $dateformat] - [string toupper [set level]]: [lrange [set args] 1 end]"
			}
			puts $logfileId $msg
			flush $logfileId
			return 0
		} else {
			return -1
		}
	} else {
		return 0
	}
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
