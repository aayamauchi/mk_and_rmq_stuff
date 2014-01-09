lappend auto_path [file dirname [info script]]

namespace eval ::monoutput {
	namespace export monoutput
	variable version 0.3
}

# define exit codes globaly
set EXIT_OK 0
set EXIT_WARNING 1
set EXIT_ERROR 2
set EXIT_UNKNOWN 3

package provide monoutput $::monoutput::version
# ::monoutput::reducenames -- internal function for reduce fields names
#
# This function removes special chars from keys in data array and
# check the keys are unique. If array item does not have long text, it
# add unmodified key name as long text.
# If reducenames not equal to 0 - keys are reduced to 19 chars by
# following algorithm:
# 1) convert to lowercase, remove "-" and "_" and make string in
#    CamelCase
# 2) remove a,e,i,o,u,y vowels when they in lowercase
# 3) remove last char in the longest word
# It executed #1-#2-#3 steps until key length becomes equal to 19.
# after this reducing key is checked for unique.
#
# if key name is not unique - function start to replace chars by
# decimal index from begin to end until key name becomes to unique.
#
# Arguments:
# data         - array as list with data for cactioutput and
#                nagiosoutput 
# ?reducenames - if not equal to 0 - reduce all key names to 19 chars
#
# Side Effects:
# None.
#
# Results:
# array as list with valid key names for nagios perfdata and cacti
# field names
proc ::monoutput::reducenames {data {reducenames 0}} {
	array set old_data $data
	array set new_data {}
	# createuniqname -- return unique name
	#
	# If name exists in names_list this function changes chars to
	# indexes from begin to end name until finds unique name
	#
	# Arguments:
	# name       - new name
	# names_list - list of exists names
	#
	# Side Effects:
	# None.
	#
	# Results:
	# string with unique name
	proc createuniqname {name names_list} {
		if {[lsearch -exact $names_list $name] == -1} {
			# unique name
			return $name
		} else {
			# add indexes to name
			set new_name $name
			# loop command for add index to specified position
			set index_loop_command "
	      for \{set posXXX 0\} \{\$posXXX <=9\} \{incr posXXX\} \{
		      set new_name \[string replace \$new_name XXX XXX \$posXXX\]
		      if \{\[lsearch -exact \$names_list \$new_name\] == -1\} \{
			      return \$new_name
		      \}
	      "
			set executed_command ""
			# create command for evaluate with needed loops
			for {set position 0} {$position < [string length $new_name]} {incr position} {
				regsub -all -- {XXX} $index_loop_command $position current_position_loop
				append executed_command $current_position_loop \} $current_position_loop
			}
			for {set positions 0} {$positions < [string length $new_name]} {incr positions} {
				append executed_command \}
			}
			eval $executed_command
		}
	}
	foreach key [lsort [array names old_data]] {
		# change invalid symbols in key
		regsub -all -expanded {[^\w-]} $key "_" newkey
		if {[llength $old_data($key)] == 1} {
			# add current unmodified  key name as long text (list index 1)
			set old_data($key) [list $old_data($key) $key]
		}
		if $reducenames {
			# reduce name to 19 chars
			if {[string length $newkey] > 19} {
				# lowercase name
				set newkey [string tolower $newkey]
				# remove "_" and convert to CamelCase
				foreach keypart [split $newkey "_-"] {
					append camel_case_key "[string toupper [string index $keypart 0]][string range $keypart 1 end]"
				}
				set newkey $camel_case_key
				unset camel_case_key
				if {[string length $newkey] > 19} {
					# next step - remove a,e,i,o,u,y vowels when they in lowercase
					regsub -all -expanded {[aeiouy]} $newkey {} without_vowels_key
					set newkey $without_vowels_key
					unset without_vowels_key
				}
				# remove last char in the word
				while {[string length $newkey] > 19} {
					# from longest to shortest
					# find longest
					regsub -all -expanded {[A-Z0-9]} $newkey { \0} new_key_with_space
					set max_length 0
					set max_length_index 0
					set newkey_list [split [string trim $new_key_with_space]]
					unset new_key_with_space
					for {set i 0} {$i < [llength $newkey_list]} {incr i} {
						if {[string length [lindex $newkey_list $i]] > $max_length} {
							set max_length [string length [lindex $newkey_list $i]]
							set max_length_index $i
						}
					}
					unset max_length
					# remove last  in longest wold
					set newkey_list [lreplace $newkey_list $max_length_index $max_length_index [string rang [lindex $newkey_list $max_length_index] 0 end-1]]
					unset max_length_index
					# build newkey from list
					set newkey [join $newkey_list {}]
					unset newkey_list
				}
			}
			# add to new_data with unique name
			set new_data([createuniqname $newkey [array names new_data]]) $old_data($key)
		} else {
			# do not reduce name length
			# add to new_data with unique name
			set new_data([createuniqname $newkey [array names new_data]]) $old_data($key)
		}
	}
	return [array get new_data]
}
# ::monoutput::textoutput -- format output for other scripts
#
# Print to stdout data in parsable format
#
# Arguments:
# ?-separator    - key/value separator (default tab)
# ?--            - flag for stop parsing arguments
# data           - array as list with field names as keys and field values
#                  as first list item in the array value.
#
# Side Effects:
# None.
#
# Results:
# None.
proc ::monoutput::textoutput {args} {
	set args $args
	set separator \t
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			-separator {
				set separator [lindex $args 1]
				set args [lrange $args 2 end]
			}
		}
	}
	array set data_array [lindex $args 0]
	foreach key [array names data_array] {
		puts "[set key][set separator][lindex $data_array($key) 0]"
	}
}
# ::monoutput::cactioutput -- format output for Cacti
#
# Print to stdout data in cacti format
#
# Arguments:
# ?-reducenames  - reduce the field names to 19 characters.
# ?--            - flag for stop parsing arguments
# data           - array as list with field names as keys and field values
#                  as first list item in the array value.
#
# Side Effects:
# None.
#
# Results:
# None.
proc ::monoutput::cactioutput {args} {
	set args $args
	set reduce_names 0
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			-reducenames {
				set reduce_names 1
				set args [lrange $args 1 end]
			}
		}
	}
	# set array with valid names
	array set data_array [::monoutput::reducenames [lindex $args 0] $reduce_names]
	foreach key [array names data_array] {
		# cacti requires decimal values of data
		if [regexp {(\.\d+)|(\d+(\.\d+)?)} [lindex $data_array($key) 0]] {
			# good value - print it
			puts -nonewline "$key:[lindex $data_array($key) 0] "
		}
	}
	puts ""
}
# ::monoutput::nagiosoutput -- format output for Nagios
#
# Print to stdout data in nagios format. When -data is specified long
# text and perfdata were printed. When -text is specified log text was
# printed (and replace long text from -data if -data is specified).
#
# Arguments:
# ?-data data_array_as_list - array as list with nagios perfdata names
#                             as keys, field values as first list item
#                             in the array value and optional long
#                             text description as second list item in
#                             the array value.
# ?-text text_list          - list with text data for nagios long text
# ?-reducenames             - reduce the field names in perfdata to 19
#                             characters 
# ?--                       - flag for stop parsing arguments
# message                   - string with printed message
#
# Side Effects:
# None.
#
# Results:
# None.
proc ::monoutput::nagiosoutput {args} {
	set args $args
	set text_list {}
	set reduce_names 0
	set perfdata_list {}
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			-data {
				set perfdata_list [lindex $args 1]
				set args [lrange $args 2 end]
			}
			-text {
				set text_list [lindex $args 1]
				set args [lrange $args 2 end]
			}
			-reducenames {
				set reduce_names 1
				set args [lrange $args 1 end]
			}
		}
	}
	proc map_chars {msg} {
		# change new line to _
		#        tabular to space
		#        | to -
		#        = to -
		# remove first and last spaces
		return [string map {\n _ \t " " | - = -} [string trim $msg]]
	}
	# write message
	puts -nonewline "[map_chars [lindex $args 0]]"
	# set array with valid names
	array set perfdata_array [::monoutput::reducenames $perfdata_list $reduce_names]
	unset perfdata_list
	# check perfdata
	set perfdata_keys [array names perfdata_array]
	if {[llength $perfdata_keys] > 0} {
		set current_key [lindex $perfdata_keys 0]
		# add perfdata to message output
		puts "|$current_key=[map_chars [lindex $perfdata_array($current_key) 0]]"
		if {[llength $text_list] == 0} {
			# when text list is empty - try to get long text from data
			if {[llength $perfdata_array($current_key)] > 1} {
				# perfdata items contain text
				puts "[map_chars [lindex $perfdata_array($current_key) 1]]"
			} else {
				# use perfdata key as text
				puts "[map_chars $current_key]"
			}
		}
		# remove processed first item
		set perfdata_keys [lreplace $perfdata_keys 0 0]
	} else {
		# no perfdata
		puts ""
	}
	# print text block
	if {[llength $text_list] != 0} {
		# print defined text block
		foreach msg [lreplace $text_list end end] {
			puts "[map_chars $msg]"
		}
		# last text string
		if {[llength $perfdata_keys] > 0} {
			# perfdata exists
			puts -nonewline "[map_chars [lindex $text_list end]]|"
		} else {
			# perfdata not exists
			puts "[map_chars [lindex $text_list end]]"
		}
	} elseif {[llength $perfdata_keys] != 0} {
		# try to print text from perfdata
		foreach current_key [lreplace $perfdata_keys end end] {
			if {[llength $perfdata_array($current_key)] > 1} {
				# perfdata items contain text
				puts "[map_chars [lindex $perfdata_array($current_key) 1]]"
			} else {
				# use perfdata key as text
				puts "[map_chars $current_key]"
			}
		}
		# last text string
		set current_key [lindex $perfdata_keys end]
		if {[llength $perfdata_array($current_key)] > 1} {
			# perfdata items contain text
			puts -nonewline "[map_chars [lindex $perfdata_array($current_key) 1]]|"
		} else {
			# use perfdata key as text
			puts -nonewline "[map_chars $current_key]|"
		}
	}
	# print perfdata
	foreach current_key $perfdata_keys {
		puts "$current_key=[map_chars [lindex $perfdata_array($current_key) 0]]"
	}
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
