# Modified Config File Parser
# first version:
# (c) Todd Coram todd@maplefish.com
# http://wiki.tcl.tk/3295

namespace eval ::opscfg {
	variable version 1.1

	variable sections [list DEFAULT]

	variable cursection DEFAULT
	variable DEFAULT;   # DEFAULT section
}

package provide opscfg $::opscfg::version

lappend auto_path [file dirname [info script]]

# CLI parser - modified function from http://wiki.tcl.tk/17342
# opscfg::getopt -- command line options parser
#
# Parse argv list for options. Support short, long and GNU-style long
# options. Also support default value for options.
#
# Arguments:
# _argv     - name of variable with argv list
# names     - list with options that are searched in _argv
# ?_var     - name of variable for searched option value (default no variable)
# ?default  - string with default value of searched option (default no value)
#
# Side Effects:
# remove found option from _argv list
# ?set found option value to _var variable
#
# Results:
# 1 when option was found
# 0 when option was not found
proc opscfg::getopt {_argv names {_var ""} {default ""}} {
	upvar 1 $_argv argv $_var var
	foreach name $names {
		if [regexp {^--.*=$} $name] {
			# GNU-style long option
			set gnu 1
			set pos [lsearch -regexp $argv ^$name.*\$]
		} else {
			set gnu 0
			set pos [lsearch -regexp $argv ^$name\$]
		}
		if {$pos>=0} {
			set to $pos
			if {$_var ne ""} {
				if $gnu {
					set var [join [lrange [split [lindex $argv $pos] "="] 1 end] "="]
				} else {
					set var [lindex $argv [incr to]]
				}
			}
			set argv [lreplace $argv $pos $to]
			return 1
		}
	}
	if {$pos<0} {
		if {[llength [info level 0]] == 5} {set var $default}
		return 0
	}
}
# opscfg::getswitchopt -- command line options parser for switches
#
# Parse argv list for options. Support short, long and GNU-style long
# options. When option was found function invert value of specified variable.
#
# Arguments:
# _argv     - name of variable with argv list
# names     - list with options that are searched in _argv
# _var      - name of variable for searched switch option value
#
# Side Effects:
# remove found option from _argv list
# ?invert value of _var variable if option was found
#
# Results:
# 1 when option was found
# 0 when option was not found
proc opscfg::getswitchopt {_argv names _var} {
	upvar 1 $_argv argv $_var var
	set result [getopt argv $names]
	if $result {
		set var [expr ! $var]
	}
	return $result
}
# opscfg::expandvalue -- expand numeric values with suffix
#
# Expand numeric value with suffix. Function is used for CLI
# parameters values conversion. For example for convert k,m,g to
# kilobytes, megabytes, gigabytes.
#
# Arguments:
# value              - string with value to expand
# expand_pairs       - list with pairs of dimension name and dimension coefficient 
# ?default_dimension - default dimension name (default empty)
#
# Side Effects:
# None.
#
# Results:
# numeric with expanded value or error if value was not expanded
proc opscfg::expandvalue {value expand_pairs {default_dimension ""}} {
	# check default value
	if [regexp -expanded "^(\\d+(\\.\\d+)?)($default_dimension)?\$" $value match numeric_value] {
			return $numeric_value
	}
	foreach {dimension_name dimension} $expand_pairs {
		if [regexp -expanded "^(\\d+(\\.\\d+)?)$dimension_name\$" $value match numeric_value] {
			return [expr $numeric_value * $dimension]
		}
	}
	error "Unable to expand value"
}
# opscfg::expandtime -- expand time values with suffix
#
# Wrapper for expandvalue function to expand time values.
#
# Arguments:
# value              - string with time to expand
#
# Side Effects:
# None.
#
# Results:
# numeric with expanded value or error if value was not expanded
proc opscfg::expandtime {value} {
	return [expandvalue $value {d "24*60*60" D "24*60*60" h "60*60" H "60*60" m 60 M 60} "s|S"]
}
# opscfg::expandsize -- expand size values with suffix
#
# Wrapper for expandvalue function to expand size values.
#
# Arguments:
# value              - string with size to expand
#
# Side Effects:
# None.
#
# Results:
# numeric with expanded value or error if value was not expanded
proc opscfg::expandsize {value} {
	return [expandvalue $value {g "1024*1024*1024" G "1024*1024*1024" m "1024*1024" M "1024*1024" k 1024 K 1024} "b|B"]
}
# opscfg::bool2text -- convert boolean (numeric) value to string
#
# Convert boolean (numeric) value to user defined string.
#
# Arguments:
# val       - numeric with converted value
# ?view     - string with true-false pair (default "on-off")
#
# Side Effects:
# None.
#
# Results:
# string with text presentation of boolean value
# or "NA" when conversion was unsuccessful
proc opscfg::bool2text {val {view "on-off"}} {
	if [regexp {^(.*?)-(.*?)$} $view match true false] {
		if {$val} {
			return $true
		} else {
			return $false
		}
	} else {
		return "NA"
	}
}
# opscfg::inlist -- check if list contains value
#
# xxx
#
# Arguments:
# list      - list
# value     - checked value
#
# Side Effects:
# None.
#
# Results:
# 1 when list contains value
# 0 when list does not contain value
proc opscfg::inlist {list value} {
	if {[lsearch -exact $list $value] == -1} {
		return 0
	} else {
		return 1
	}
}
# opscfg::sections -- return list of sections
#
# Return list of sections in the parsed configuration file.
#
# Arguments:
# None.
#
# Side Effects:
# None.
#
# Results:
# list with sections names
proc opscfg::sections {} {
	return $opscfg::sections
}
# opscfg::variables -- return list of section variables names
#
# Return list of variables names in the specified section in the
# parsed configuration file.
#
# Arguments:
# ?section  - string with section name
#
# Side Effects:
# None.
#
# Results:
# list with variables names in the section
proc opscfg::variables {{section DEFAULT}} {
	return [array names ::opscfg::$section]
}
# opscfg::add_section -- add new section
#
# Add new section to the parsed configuration file.
#
# Arguments:
# str       - string with section name
#
# Side Effects:
# Add new section to sections variable in the opscfg namespace.
#
# Results:
# None.
proc opscfg::add_section {str} {
	variable sections
	variable cursection

	set cursection [string trim $str \[\]]
	if {[lsearch -exact $sections $cursection] == -1} {
		lappend sections $cursection
		variable ::opscfg::${cursection}
	}
}
# opscfg::setvar -- set variable value in the specified section
#
# Add new variable if needed and set it value in the specified section
# of the parsed configuration file
#
# Arguments:
# varname   - string with variable name
# value     - string with value of specified variable
# ?section  - string with section name (default "DEFAULT")
#
# Side Effects:
# Add new section (if needed), new variable and set variable value in
# the opscfg namespace.
#
# Results:
# None.
proc opscfg::setvar {varname value {section DEFAULT}} {
	variable sections
	if {[lsearch -exact $sections $section] == -1} {
		opscfg::add_section $section
	}
	set ::opscfg::${section}($varname) $value
}
# opscfg::getvar -- return value of the specified variable
#
# Return value of specified variable in the specified section of the
# parsed configuration file.
#
# Arguments:
# varname   - string with variable name
# ?section  - string with section name (default "DEFAULT")
#
# Side Effects:
# None.
#
# Results:
# string with variable value
# error when variable does not exists
proc opscfg::getvar {varname {section DEFAULT}} {
	variable sections
	if {[lsearch -exact $sections $section] == -1} {
		error "No such section: $section"
	}
	return [set ::opscfg::${section}($varname)]
}
# opscfg::parseini -- parse INI-style structure
#
# Parse INI-style structure specified as string.
#
# Arguments:
# ini    - string with INI-style structure
#
# Side Effects:
# Change sections and cursections variables in the opscfg namespace.
#
# Results:
# None or error when INI-style structure can not be parsed
proc opscfg::parseini {ini} {
	variable sections
	variable cursection
	set line_no 1
	foreach line [split $ini "\n"] {
		set line [string trim $line " "]
		if {$line == ""} continue
		switch -regexp -- $line {
			^#.* { }
			^\\[.*\\]$ {
				opscfg::add_section $line
			}
			.*=.* {
				set pair [split $line =]
				set name [string trim [lindex $pair 0] " "]
				set value [string trim [lindex $pair 1] " "]
				opscfg::setvar $name $value $cursection
			}
			default {
				error "Error parsing INI structure (line: $line_no): $line"
			}
		}
		incr line_no
	}
}
# opscfg::parse_file -- parse INI-style configuration file
#
# Parse INI-style configuration file specified by path.
#
# Arguments:
# filename  - string with configuration file path
#
# Side Effects:
# Change sections and cursections variables in the opscfg namespace.
#
# Results:
# None or error when configuration file can not be read or parsed
proc opscfg::parse_file {filename} {
	set fd [open $filename r]
	if [catch {parseini [read $fd]} error_message] {
		error "Error parsing $filename : $error_message"
	}
	close $fd
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
