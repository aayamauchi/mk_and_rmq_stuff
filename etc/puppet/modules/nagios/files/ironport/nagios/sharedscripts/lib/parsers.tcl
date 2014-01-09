lappend auto_path [file dirname [info script]]

namespace eval ::opsparsers {
	namespace export opsparsers
	variable version 0.2
}

package provide opsparsers $::opsparsers::version

############################################
# Turn HTML into TCL commands
#   html    A string containing an html document
#   cmd                A command to run for each html tag found
#   start        The name of the dummy html start/stop tags
# ::opsparsers::HMparse_html -- simply HTML parser
#
# Modified Stephen Uhler's HTML parser in 10 lines
# This function parse html and run function specified in cmd variable
# for every tag. 
#
# Arguments:
# html     - string with html for parsing
# ?cmd     - name of executed function for processing tags
# ?start   - pseudo tag to start parsing
#
# Side Effects:
# None.
# But this function executes function specified in cmd and cmd
# function can has side effects.
#
# Results:
# None.
# But this function executes function specified in cmd and cmd
# function can return results.
proc ::opsparsers::HMparse_html {html {cmd HMtest_parse} {start hmstart}} {
	# map {} to html sequences
	regsub -all \{ $html {\&ob;} html
	regsub -all \} $html {\&cb;} html
	# convert short tags to classic
	regsub -all -expanded {(<(\w+?)(\s[^>]*?)?)/>} $html {\1></\2>} html
	set w " \t\r\n"        ;# white space
	# function which add brackets to string
	proc HMcl x {return "\[$x\]"}
	# make parameters for executing cmd
	set exp <(/?)([HMcl ^$w>]+)[HMcl $w]*([HMcl ^>]*)>
	set sub "\}\n$cmd {\\2} {\\1} {\\3} \{"
	regsub -all $exp $html $sub html
	# execute cmd with params
	eval "$cmd {$start} {} {} \{ $html \}"
	eval "$cmd {$start} / {} {}"
}
# ::opsparsers::HMtest_parse -- test function for html parser
#
# This function is called from HMparse_html and just print results of
# parsing.
#
# Arguments:
# tag     - string with html tag name
# state   - string with html tag state (empty string for open tag, "/"
#           for close tag)
# props   - string with html tag properties
# body    - string with html tag body
#
# Side Effects:
# None.
#
# Results:
# None.
proc ::opsparsers::HMtest_parse {tag state props body} {
	if {$state == ""} {
		set msg "Start $tag"
		if {$props != ""} {
			set msg "$msg with args: $props"
		}
		set msg "$msg\n$body"
	} else {
		set msg "End $tag"
	}
	puts $msg
}
# ::opsparsers::unmap_html -- unmap html sequences to chars
#
# This function convert html sequences to appropriate chars
# for example &amp; to &
#
# Arguments:
# html   - string with html text to conversion
#
# Side Effects:
# None.
#
# Results:
# string with unmapped chars
proc ::opsparsers::unmap_html {html} {
	foreach {from to} {{&quot;} \" \
											 {&amp;} & \
											 {&lt;} < \
											 {&gt;} > \
											 {&ob;} \{ \
											 {&cb;} \}} {
		regsub -all $from $html $to html
	}
	return $html
}
# ::opsparsers::json2array -- convert JSON to array as list
#
# This function converts JSON to array as list ready to array set
# command
# modified json2dict method from tcllib
#
# Arguments:
# txt    - string variable with JSON
#
# Side Effects:
# None.
#
# Results:
# array as list with data from provided JSON
proc ::opsparsers::json2array {txt} {
	return [_json2array]
}
proc ::opsparsers::_json2array {{txtvar txt}} {
	upvar 1 $txtvar txt
	proc getc {{txtvar txt}} {
    # pop single char off the front of the text
    upvar 1 $txtvar txt
    if {$txt eq ""} {
    	return -code error "unexpected end of text"
    }
    set c [string index $txt 0]
    set txt [string range $txt 1 end]
    return $c
	}

	# initial state
	set state TOP
	set txt [string trimleft $txt]
	while {$txt ne ""} {
		set c [string index $txt 0]

		# skip whitespace
		while {[string is space $c]} {
			getc
			set c [string index $txt 0]
		}

		if {$c eq "\{"} {
	    # object
	    switch -- $state {
				TOP {
					# we are dealing with an Object
					getc
					set state OBJECT
					array set arrayVal {}
				}
				VALUE {
					# this object element's value is an Object
					set arrayVal($name) [_json2array]
					set state COMMA
				}
				LIST {
					# next element of list is an Object
					lappend listVal [_json2array]
					set state COMMA
				}
				default {
					return -code error "unexpected open brace in $state mode"
				}
	    }
		} elseif {$c eq "\}"} {
	    getc
	    if {$state ne "OBJECT" && $state ne "COMMA"} {
				return -code error "unexpected close brace in $state mode"
	    }
	    return [array get arrayVal]
		} elseif {$c eq ":"} {
	    # name separator
	    getc

	    if {$state eq "COLON"} {
				set state VALUE
	    } else {
				return -code error "unexpected colon in $state mode"
	    }
		} elseif {$c eq ","} {
	    # element separator
	    if {$state eq "COMMA"} {
				getc
				if {[info exists listVal]} {
					set state LIST
				} elseif {[array exists arrayVal]} {
					set state OBJECT
				}
	    } else {
				return -code error "unexpected comma in $state mode"
	    }
		} elseif {($c eq "\"") || ($c eq "'")} {
	    # string
	    # capture quoted string with backslash sequences
	    set reStr {(?:(?:[\"'])(?:[^\\\"']*(?:\\.[^\\\"']*)*)(?:[\"']))}
	    set string ""
	    if {![regexp $reStr $txt string]} {
				set txt [string replace $txt 32 end ...]
				return -code error "invalid formatted string in $txt"
	    }
	    set txt [string range $txt [string length $string] end]
	    # chop off outer ""s and substitute backslashes
	    # This does more than the RFC-specified backslash sequences,
	    # but it does cover them all
	    set string [subst -nocommand -novariable \
										[string range $string 1 end-1]]

	    switch -- $state {
				TOP {
					return $string
				}
				OBJECT {
					set name $string
					set state COLON
				}
				LIST {
					lappend listVal $string
					set state COMMA
				}
				VALUE {
					set arrayVal($name) $string
					unset name
					set state COMMA
				}
	    }
		} elseif {$c eq "\["} {
	    # JSON array == Tcl list
	    switch -- $state {
				TOP {
					getc
					set state LIST
				}
				LIST {
					lappend listVal [_json2array]
					set state COMMA
				}
				VALUE {
					set arrayVal($name) [_json2array]
					set state COMMA
				}
				default {
					return -code error "unexpected open bracket in $state mode"
				}
	    }
		} elseif {$c eq "\]"} {
	    # end of list
	    getc
	    if {![info exists listVal]} {
				#return -code error "unexpected close bracket in $state mode"
				# must be an empty list
				return ""
	    }

	    return $listVal
		} elseif {0 && $c eq "/"} {
	    # comment
	    # XXX: Not in RFC 4627
	    getc
	    set c [getc]
	    switch -- $c {
				/ {
					# // comment form
					set i [string first "\n" $txt]
					if {$i == -1} {
						set txt ""
					} else {
						set txt [string range $txt [incr i] end]
					}
				}
				* {
					# /* comment */ form
					getc
					set i [string first "*/" $txt]
					if {$i == -1} {
						return -code error "incomplete /* comment"
					} else {
						set txt [string range $txt [incr i] end]
					}
				}
				default {
					return -code error "unexpected slash in $state mode"
				}
	    }
		} elseif {[string match {[-0-9]} $c]} {
	    # one last check for a number, no leading zeros allowed,
	    # but it may be 0.xxx
	    string is double -failindex last $txt
	    if {$last > 0} {
				set num [string range $txt 0 [expr {$last - 1}]]
				set txt [string range $txt $last end]

				switch -- $state {
					TOP {
						return $num
					}
					LIST {
						lappend listVal $num
						set state COMMA
					}
					VALUE {
						set arrayVal($name) $num
						set state COMMA
					}
					default {
						getc
						return -code error "unexpected number '$c' in $state mode"
					}
				}
	    } else {
				getc
				return -code error "unexpected '$c' in $state mode"
	    }
		} elseif {[string match -nocase {[ftn]} $c]
							&& [regexp -- {^([Tt]rue|[Ff]alse|[Nn]ull|[Nn]one)} $txt val]} {
	    # bare word value: true | false | null | none
	    set txt [string range $txt [string length $val] end]

	    switch -- $state {
				TOP {
					return $val
				}
				LIST {
					lappend listVal $val
					set state COMMA
				}
				VALUE {
					set arrayVal($name) $val
					set state COMMA
				}
				default {
					getc
					return -code error "unexpected '$c' in $state mode"
				}
	    }
		} else {
	    # error, incorrect format or unexpected end of text
	    return -code error "unexpected '$c' in $state mode"
		}
	}
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
