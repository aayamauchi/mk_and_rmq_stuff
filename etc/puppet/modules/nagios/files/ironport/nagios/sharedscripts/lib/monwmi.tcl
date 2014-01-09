lappend auto_path [file dirname [info script]]

namespace eval ::monwmi {
	namespace export monwmi
	variable version 0.1
	variable wmi_idx 0
}

package provide monwmi $::monwmi::version
# ::monwmi::openwmi -- create namespace with WMI client parameters
#
# Create new namespace for WMI client and fill specified values to it.
#
# Arguments:
# ?-retry retrycount                    - numeric with wmi command retry attempts before error
# ?-command wmiclientcommandname        - string with WMI CLI utility name (default wmic)
# ?-commandargs wmiclientCLIarguments   - list with WMI CLI utility parameters
# ?-host wmihostname                    - string with WMI server hostname
# ?-username wmiusername                - string with username
# ?-password wmipassword                - string with password
# ?-domain smbdomain                    - string with user domain
# ?-workgroup smbworkgroup              - string with used workgroup
# ?-smbconfig configurationfile         - string with path to alternative Samba configuration file
# ?-smboptions optionslist              - list of smb options (pairs name value)
# ?-wminamespace WMInamespace           - string with WMI namespace (default root\cimv2)
# ?--                                   - flag for stop parsing arguments
#
# Side Effects:
# Create new namespace monwmi::wmiN with wmi client settings
# variables.
#
# Results:
# string with new wmi client namespace name
proc ::monwmi::openwmi {args} {
	variable wmi_idx
	incr wmi_idx
	namespace eval ::monwmi::wmi[set wmi_idx] {
		variable retry 1
		variable command "wmic"
		variable commandargs ""
		variable host ""
		variable username ""
		variable wminamespace "root\\cimv2"
	} 
	set args $args
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			{-retry} -
			{-command} -
			{-commandargs} -
			{-host} -
			{-username} -
			{-password} -
			{-domain} -
			{-workgroup} -
			{-smbconfig} -
			{-smboptions} -
			{-wminamespace} {
				set ::monwmi::wmi[set wmi_idx]::[string trimleft $arg "-"] [lindex $args 1]
				set args [lrange $args 2 end]
			}
		}
	}
	return "wmi[set wmi_idx]"
}
# ::monwmi::closewmi -- delete namespace with wmi client parameters
#
# Delete specified namespace with wmi parameters
#
# Arguments:
# wmiId   - string with wmi client namespace name
#
# Side Effects:
# Delete appropriate wmi namespace monwmi::wmiN with wmi client
# settings variables.
#
# Results:
# 0 when function is worked successfully
# -1 when log namespace does not exists
proc ::monwmi::closewmi {wmiId} {
	if [namespace exists ::monwmi::[set wmiId]] {
		namespace delete ::monwmi::[set wmiId]
		return 0
	} else {
		return 1
	}
}
# ::monwmi::wmi -- run WMI queue on server
#
# Run WMI queue on specified server and return formated result.
# When wmi client namespace is specified this function get
# parameters for wmi client from specified namespace and other
# optional arguments overrides appropriate values.
# When wmi client namespace is not specified you must define all
# other optional arguments.
#
# Arguments:
# ?-wmiId                               - string with wmi client namespace name
# ?-retry retrycount                    - numeric with wmi command retry attempts before error
# ?-command wmiclientcommandname        - string with wmi CLI utility name (default wmic)
# ?-commandargs wmiclientCLIarguments   - list with wmi CLI utility parameters
# ?-host wmihostname                    - string with WMI server hostname
# ?-username wmiusername                - string with username
# ?-password wmipassword                - string with password
# ?-domain smbdomain                    - string with user domain
# ?-workgroup smbworkgroup              - string with used workgroup
# ?-smbconfig configurationfile         - string with path to alternative Samba configuration file
# ?-smboptions optionslist              - list of smb options (pairs name value)
# ?-wminamespace WMInamespace           - string with WMI namespace (default root\cimv2)
# ?--                                   - flag for stop parsing arguments
# wmiqueue                              - string with SQL queue to execute
#
# Side Effects:
# None.
#
# Results:
# list with arrays as list which contains data returned from server. Format of this structure is:
# { component {fieldname1 value2 fieldname2 value2 ...}}
# where list items is an array as list (array get result) with row content.
# Error when wmi client namespace was not found
# Error when wmi command worked with error
proc ::monwmi::wmi {args} {
	set args $args
	foreach arg $args {
		switch -exact -- $arg {
			{--} {
				# end options
				set args [lrange $args 1 end]
				break
			}
			{-wmiId} -
			{-retry} -
			{-command} -
			{-commandargs} -
			{-host} -
			{-username} -
			{-password} -
			{-domain} -
			{-workgroup} -
			{-smbconfig} -
			{-smboptions} -
			{-wminamespace} {
				set [string trimleft $arg "-"] [lindex $args 1]
				set args [lrange $args 2 end]
			}
		}
	}
	# when wmiId is set - get unconfigured values from namespace
	if [info exists wmiId] {
		if [namespace exists ::monwmi::[set wmiId]] {
			foreach variable_name {retry command commandargs host username password domain workgroup smbconfig smboptions wminamespace} {
				# get access to needed variables
				if ![info exists $variable_name] {
					variable ::monwmi::[set wmiId]::[set variable_name]
				}
			}
		} else {
			# unknown wmiId
			error "Unknown wmi client: $wmiId"
		}
	}
	# drop command separator from WMI queue if needed
	set wmiqueue [string trimright [lindex $args 0] {; }]
	# make command list
	set wmic $commandargs
	set credentials $username
	# check password
	if [info exists password] {
		set credentials "[set credentials]%[set password]"
	} else {
		lappend wmic "-N"
	}
	if [info exists domain] {
		set credentials "[set domain]/[set credentials]"
	}
	lappend wmic "-U" $credentials
	unset credentials
	foreach {var opt} {workgroup --workgroup smbconfig --configfile wminamespace --namespace} {
		if [info exists [set var]] {
			lappend wmic "[set opt]=[set [set var]]"
		}
	}
	for {set i 0} {$i < $retry} {incr i} {
		if ![catch {eval [list exec $command] [lrange $wmic 0 end] [list "//[string trim $host {/ }]" $wmiqueue 2>@ stdout]} wmi_output] {
			break
		}
	}
	# check is command executed successful
	if {$i >= $retry} {
		# got error
		error $wmi_output
	}
	array unset result_array
	set wmi_output [split $wmi_output "\n"]
	# search class name
	set class_idx [lsearch -regexp $wmi_output {^CLASS:}]
	if {$class_idx != -1} {
		set class_name [string trim [ \
		                                string range [lindex $wmi_output $class_idx] [string length "CLASS:"] end] \
		                  " "]
		set result_array($class_name) {}
		if {[llength $wmi_output] >= [expr $class_idx + 2]} {
			# header and value strings are present
			set headers_list [split [lindex $wmi_output [expr $class_idx + 1]] "|"]
			set values_list [split [lindex $wmi_output [expr $class_idx + 2]] "|"]
			for {set idx 0} {$idx < [llength $headers_list]} {incr idx} {
				lappend result_array($class_name) [lindex $headers_list $idx] [lindex $values_list $idx]
			}
		}
		return [array get result_array]
	} else {
		# class name not found
		return {}
	}
}

# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
