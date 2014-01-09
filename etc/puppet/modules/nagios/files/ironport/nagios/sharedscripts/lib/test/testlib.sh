#!/bin/sh
#\
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
# specify tcl prefer version \
TCL=tclsh
# prefer versions 8.2 -> 8.3 -> 8.4 -> 8.6 -> 8.5 \
for v in 8.2 8.3 8.4 8.6 8.5; do type tclsh$v >/dev/null 2>&1 && TCL=tclsh$v; done
# the next line restarts using tclsh \
exec $TCL "$0" ${1+"$@"}

# add path to local library
set script_path [file dirname [info script]]
lappend auto_path [file join $script_path ".."]

proc hputs {msg} {
	puts "\033\[1m$msg\033\[0m"
}
proc pputs {msg} {
	puts "\033\[32m$msg\033\[0m"
}
proc fputs {msg} {
	puts "\033\[31m$msg\033\[0m"
}

########## check opscfg
package require opscfg
hputs "Checking opscfg package"
## getopt checks
puts -nonewline "\tgetopt checks..."
if [opscfg::getopt argv [list "-a" "--aaa"]] {
	if [opscfg::getopt argv [list "--testopt"]] {
		if {![opscfg::getopt argv [list "-c" "--ccc"]]} {
			set param1 ""
			set param2 ""
			set param3 "NA"
			set gnuopt ""
			opscfg::getopt argv [list "-b" "--bbb"] param1
			opscfg::getopt argv [list "-z" "--testparam"] param2 "defval"
			opscfg::getopt argv [list "-y" "--testparam2"] param3
			opscfg::getopt argv [list "-x" "--testparam3"] param4 "defaultvalue"
			opscfg::getopt argv [list "--gnuopt="] gnuopt "defaultvalue"
			if {($param1 == "param1") && ($param2 == "param2") && ($param3 == "NA") && ($param4 == "defaultvalue") && ($gnuopt == "gnuoptvalue")} {
				pputs "\t passed"
			} else {
				fputs "\t failed1"
			}
		} else {
			fputs "\t failed2"
		}
	} else {
		fputs "\t failed3"
	}
} else {
	fputs "\t failed4"
}
puts -nonewline "\tbool2text checks..."
if {([opscfg::bool2text 0] == "off") && ([opscfg::bool2text 1] == "on") && ([opscfg::bool2text 0 "true-false"] == "false") && ([opscfg::bool2text 1 "true-false"] == "true") && ([opscfg::bool2text 0 "blabla"] == "NA") && ([opscfg::bool2text 1 "blabla"] == "NA")} {
	pputs "\t passed"
} else {
	pfuts "\t failed"
}
puts -nonewline "\texpandvalue checks..."
if {([opscfg::expandvalue 100 {d "24*60*60" h "60*60" m "60"}] == 100) && ([opscfg::expandvalue 100s {d "24*60*60" h "60*60" m "60"} s] == 100) && ([opscfg::expandvalue 2m {d "24*60*60" h "60*60" m "60"}] == 120) && ([opscfg::expandvalue 2h {d "24*60*60" h "60*60" m "60"}] == 7200) && ([opscfg::expandvalue 1d {d "24*60*60" h "60*60" m "60"} "s"] == 86400)} {
	pputs "\t passed"
} else {
	fputs "\t failed"
}
puts -nonewline "\tconfigparser checks..."
if {[catch {opscfg::parse_file [file join $script_path "test.conf"]} res]} {
	error "Couldn't find the configuration file"
}
# check sections
if {[opscfg::inlist [opscfg::sections] "DEFAULT"] && [opscfg::inlist [opscfg::sections] "DB"] && [opscfg::inlist [opscfg::sections] "log"]} {
	# check default section
	if {([opscfg::inlist [opscfg::variables "DEFAULT"] test1]) && ([opscfg::inlist [opscfg::variables "DEFAULT"] test2]) && (![opscfg::inlist [opscfg::variables "DEFAULT"] test3])} {
		# check default variables
		if {([opscfg::getvar test1 DEFAULT] == "param1") && ([opscfg::getvar test2 DEFAULT] == "param2")} {
			# check add sections / variables
			opscfg::add_section "testsection"
			opscfg::setvar test3 param3
			opscfg::setvar test4 param4 "testsection"
			if {([opscfg::inlist [opscfg::sections] "testsection"]) && ([opscfg::getvar test3 DEFAULT] == "param3") && ([opscfg::getvar test4 testsection] == "param4")} {
				pputs "\t passed"
			} else {
				fputs "\t failed1"
			}
		} else {
			fputs "\t failed2"
		}
	} else {
		fputs "\t failed3"
	}
} else {
	fputs "\t failed4"
}
hputs "Checking opscfg package COMPLETE"

# get params for log
set logfile [opscfg::getvar "file" "log"]
# delete if exists
if [file writable $logfile] {
	file delete -force $logfile
}
hputs "Checking opslogger package"
package require opslogger
puts -nonewline "\tchecking log with app name and custom datetime..."
set logger [opslogger::openlog -dateformat {%Y-%m-%d} -appname "TEST1"  -- $logfile]
foreach l {-debug -info -warning -error} {
	if [opslogger::putslog $l -- $logger "test $l"] {
		fputs "\t failed1"
		break
	}
}
if [opslogger::closelog $logger] {
	fputs "\t failed2"
} else {
	pputs "\t passed"
}
puts -nonewline "\tchecking generated log..."
set fileId [open $logfile r]
set log [read $fileId]
close $fileId
if {(![regexp {^\d+-\d+-\d+ - TEST1: DEBUG: test -debug} [lindex [split $log "\n"] 0]]) || (![regexp {^\d+-\d+-\d+ - TEST1: INFO: test -info} [lindex [split $log "\n"] 1]]) || \
			(![regexp {^\d+-\d+-\d+ - TEST1: WARNING: test -warning} [lindex [split $log "\n"] 2]]) || (![regexp {^\d+-\d+-\d+ - TEST1: ERROR: test -error} [lindex [split $log "\n"] 3]])} {
	fputs "\t failed"
} else {
	pputs "\t passed"
}

puts -nonewline "\tchecking log with app name..."
set logger [opslogger::openlog -appname "TEST2"  -- $logfile]
foreach l {-debug -info -warning -error} {
	if [opslogger::putslog $l -- $logger "test $l"] {
		fputs "\t failed1"
		break
	}
}
if [opslogger::closelog $logger] {
	fputs "\t failed2"
} else {
	pputs "\t passed"
}
puts -nonewline "\tchecking generated log..."
set fileId [open $logfile r]
set log [read $fileId]
close $fileId
if {(![regexp {^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M - TEST2: DEBUG: test -debug} [lindex [split $log "\n"] 4]]) || \
			(![regexp {^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M - TEST2: INFO: test -info} [lindex [split $log "\n"] 5]]) || \
			(![regexp {^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M - TEST2: WARNING: test -warning} [lindex [split $log "\n"] 6]]) || \
			(![regexp {^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M - TEST2: ERROR: test -error} [lindex [split $log "\n"] 7]])} {
	fputs "\t failed"
} else {
	pputs "\t passed"
}

puts -nonewline "\tchecking log (default values)..."
set logger [opslogger::openlog $logfile]
foreach l {-debug -info -warning -error} {
	if [opslogger::putslog $l -- $logger "test $l"] {
		fputs "\t failed1"
		break
	}
}
if [opslogger::closelog $logger] {
	fputs "\t failed2"
} else {
	pputs "\t passed"
}
puts -nonewline "\tchecking generated log..."
set fileId [open $logfile r]
set log [read $fileId]
close $fileId
if {(![regexp {^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M - DEBUG: test -debug} [lindex [split $log "\n"] 8]]) || \
			(![regexp {^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M - INFO: test -info} [lindex [split $log "\n"] 9]]) || \
			(![regexp {^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M - WARNING: test -warning} [lindex [split $log "\n"] 10]]) || \
			(![regexp {^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M - ERROR: test -error} [lindex [split $log "\n"] 11]])} {
	fputs "\t failed"
} else {
	pputs "\t passed"
}
if [file writable $logfile] {
	file delete -force $logfile
}
hputs "Checking opslogger package COMPLETE"

hputs "Checking opsdb (mysql) package"
package require opsdb
set mysqlId [opsdb::openmysql -retry 2 -host [opscfg::getvar host DB] -username [opscfg::getvar username DB] -password [opscfg::getvar password DB] -database [opscfg::getvar database DB] -port [opscfg::getvar port DB]]
puts -nonewline "\tchecking select from database..."
set mysql_result [opsdb::mysql -mysqlId $mysqlId "select * from testdata"]
array set rec_arr0 [lindex $mysql_result 0]
array set rec_arr1 [lindex $mysql_result 1]
array set rec_arr2 [lindex $mysql_result 2]
if {($rec_arr0(id) == 3) && ($rec_arr0(strdata) == "0. test string 1") && ($rec_arr0(strdata2) == "test string 2") && ($rec_arr0(textdata) == "\[\"magic.mime\",\n\"magic_v5.mime\"\]") && ($rec_arr0(tinyintdata) == 1) && \
		($rec_arr1(id) == 4) && ($rec_arr1(strdata) == "1. test string 1") && ($rec_arr1(strdata2) == "NULL") && ($rec_arr1(textdata) == "\[\"magic.mime\",\n\"magic_v5.mime\"\]") && ($rec_arr1(tinyintdata) == 0) && \
		($rec_arr2(id) == 5) && ($rec_arr2(strdata) == "2. test string 1") && ($rec_arr2(strdata2) == "NULL") && ($rec_arr2(textdata) == "NULL") && ($rec_arr2(tinyintdata) == 0)} {
	pputs "\t passed"
} else {
	fputs "\t failed"
}
puts -nonewline "\tchecking insert to database..."
set mysql_result [opsdb::mysql -mysqlId $mysqlId "insert into testdata (`strdata`) values ('new string')"]
set mysql_result [opsdb::mysql -mysqlId $mysqlId "select id from testdata where strdata like 'new%'"]
array unset rec_arr0
array set rec_arr0 [lindex $mysql_result 0]
if {([llength $mysql_result] == 1) && ($rec_arr0(id) == 6)} {
	pputs "\t passed"
} else {
	fputs "\t failed"
}
puts -nonewline "\tchecking select nonexistent record from database..."
set mysql_result [opsdb::mysql -mysqlId $mysqlId "select id from testdata where strdata like 'bla%'"]
if {[llength $mysql_result] == 0} {
	pputs "\t passed"
} else {
	fputs "\t failed"
}
opsdb::closemysql $mysqlId
hputs "Checking opsdb (mysql) package COMPLETE"

hputs "Checking opsssh package"
package require opsssh
set sshId [opsssh::openssh -retry 1 -host [opscfg::getvar host ssh]]
puts -nonewline "\tchecking ssh command execution using nopassword key..."
set ssh_result [opsssh::ssh -sshId $sshId "ls -la"]
if {[lsearch -regexp $ssh_result {^-rw.*\s+\d+\s+.*\s+\.bashrc$}] != -1} {
	pputs "\t passed"
} else {
	fputs "\t failed"
}
opsssh::closessh $sshId
proc getpass {prompt} {
  # Required package is Expect. It could be installed using teacup:
  # teacup install Expect
  package require Expect
  set oldmode [stty -echo -raw]
  send_user "$prompt"
  set timeout -1
  expect_user -re "(.*)\n"
  send_user "\n"
  eval stty $oldmode
  return $expect_out(1,string)
}
set password [getpass "[opscfg::getvar username ssh-password] SSH password for [opscfg::getvar host ssh-password]: "]
puts -nonewline "\tchecking ssh command execution using password..."
set ssh_result [opsssh::ssh -host [opscfg::getvar host ssh-password] -port [opscfg::getvar port ssh-password] -username [opscfg::getvar username ssh-password] -password $password -command ssh -commandargs {-o StrictHostKeyChecking=no} -retry 1 "ls -la"]
if {[lsearch -regexp $ssh_result {^-rw.*\s+\d+\s+.*\s+.bashrc$}] != -1} {
	pputs "\t passed"
} else {
	fputs "\t failed"
}
hputs "Checking opsssh package COMPLETE"
hputs "Checking mondiablo package"
package require mondiablo
hputs "\tHTML parser from opsparsers"
set fileId [open [file join $script_path "diablocounters.html"] r]
set HTML_counters [read $fileId]
close $fileId
array set diablo_counters_array [::mondiablo::parsecounters $HTML_counters]
puts -nonewline "\tchecking counters parser..."
set failed_result 0
set components {alexa avc_daemon ca_tier1 ham_whitelist hostname inspector quantcast surbl_whitelist wbnp_high_volume wbnp_nocat webcat_complaints webcat_merge_low webcat_user_site}
if {[lsort -increasing [array names diablo_counters_array]] == $components} {
	foreach {component_name counter_name counter_type counter_values_list} {ca_tier1 domains_added_last_time st {"current value" 31} \
																																						ca_tier1 times_processed dyn {"current value" 41 "current rate" 0.000 "average rate" 0.000} \
																																						ca_tier1 last_processing_time st {"current value" 0} \
																																						ca_tier1 domains_added_total dyn {"current value" 716 "current rate" 0.000 "average rate" 0.001} \
																																						webcat_user_site times_processed dyn {{current value} 4 {current rate} 0.000 {average rate} 0.000} \
																																						webcat_user_site domains_added_last_time st {{current value} 358} \
																																						webcat_user_site last_processing_time st {{current value} 1} \
																																						webcat_user_site domains_added_total dyn {{current value} 1770 {current rate} 0.000 {average rate} 0.002} \
																																						inspector domains_added_last_time st {{current value} 3194} \
																																						inspector times_processed dyn {{current value} 3 {current rate} 0.000 {average rate} 0.000} \
																																						inspector last_processing_time st {{current value} 434} \
																																						inspector domains_added_total dyn {{current value} 18294 {current rate} 0.000 {average rate} 0.024} \
																																						webcat_complaints domains_added_last_time st {{current value} 7} \
																																						webcat_complaints times_processed dyn {{current value} 73 {current rate} 0.001 {average rate} 0.000} \
																																						webcat_complaints last_processing_time st {{current value} 0} \
																																						webcat_complaints domains_added_total dyn {{current value} 832 {current rate} 0.004 {average rate} 0.001} \
																																						ham_whitelist times_processed dyn {{current value} 9 {current rate} 0.000 {average rate} 0.000} \
																																						ham_whitelist domains_added_last_time st {{current value} 0} \
																																						ham_whitelist last_processing_time st {{current value} 20} \
																																						ham_whitelist domains_added_total dyn {{current value} 201 {current rate} 0.000 {average rate} 0.000} \
																																						alexa times_processed dyn {{current value} 11 {current rate} 0.000 {average rate} 0.000} \
																																						alexa domains_added_last_time st {{current value} 0} \
																																						alexa last_processing_time st {{current value} 421} \
																																						alexa domains_added_total dyn {{current value} 5707 {current rate} 0.000 {average rate} 0.005} \
																																						wbnp_nocat times_processed dyn {{current value} 66 {current rate} 0.003 {average rate} 0.000} \
																																						wbnp_nocat domains_added_last_time st {{current value} 5000} \
																																						wbnp_nocat last_processing_time st {{current value} 102} \
																																						wbnp_nocat domains_added_total dyn {{current value} 223156 {current rate} 16.639 {average rate} 0.214} \
																																						quantcast domains_added_last_time st {{current value} 0} \
																																						quantcast times_processed dyn {{current value} 5 {current rate} 0.000 {average rate} 0.000} \
																																						quantcast last_processing_time st {{current value} 408} \
																																						quantcast domains_added_total dyn {{current value} 0 {current rate} 0.000 {average rate} 0.000} \
																																						surbl_whitelist domains_added_last_time st {{current value} 0} \
																																						surbl_whitelist times_processed dyn {{current value} 3 {current rate} 0.000 {average rate} 0.000} \
																																						surbl_whitelist last_processing_time st {{current value} 26} \
																																						surbl_whitelist domains_added_total dyn {{current value} 1 {current rate} 0.000 {average rate} 0.000} \
																																						avc_daemon last_successful_update_published ts {{current value} 1364903852} \
																																						wbnp_high_volume times_processed dyn {{current value} 76 {current rate} 0.000 {average rate} 0.000} \
																																						wbnp_high_volume domains_added_last_time st {{current value} 0} \
																																						wbnp_high_volume last_processing_time st {{current value} 196} \
																																						wbnp_high_volume domains_added_total dyn {{current value} 113049 {current rate} 0.000 {average rate} 0.107} \
																																						webcat_merge_low times_processed dyn {{current value} 4 {current rate} 0.000 {average rate} 0.000} \
																																						webcat_merge_low domains_added_last_time st {{current value} 3978} \
																																						webcat_merge_low last_processing_time st {{current value} 1595} \
																																						webcat_merge_low domains_added_total dyn {{current value} 17023 {current rate} 0.000 {average rate} 0.017} \
																																						hostname domains_added_last_time st {{current value} 1633} \
																																						hostname times_processed dyn {{current value} 28 {current rate} 0.000 {average rate} 0.000} \
																																						hostname last_processing_time st {{current value} 87} \
																																						hostname domains_added_total dyn {{current value} 23852 {current rate} 0.000 {average rate} 0.023}} {
		array unset counters_array
		array unset counter_array
		array set counters_array $diablo_counters_array($component_name)
		array set counter_array $counters_array($counter_name)
		if {$counter_array(type) == $counter_type} {
			foreach {name value} $counter_values_list {
				if {$counter_array($name) != $value} {
					fputs "\t failed1"
puts "counter $component_name/$counter_name $name = $counter_array($name) but required $value"
					set failed_result 1
					break
				}
			}
		} else {
			fputs "\t failed2"
			break
		}
		if $failed_result {
			break
		}
	}
} else {
	fputs "\t failed3"
	set failed_result 1
}
if !$failed_result {
	pputs "\t passed"
}
hputs "\tJSON parser from opsparsers"
set fileId [open [file join $script_path "diablocounters.json"] r]
set HTML_counters [read $fileId]
close $fileId
array set diablo_counters_array2 [::mondiablo::parsecounters $HTML_counters]
puts -nonewline "\tchecking counters parser..."
set failed_result 0
if {[lsort [array names diablo_counters_array]] != [lsort [array names diablo_counters_array2]]} {
	fputs "\t failed1"
} else {
	foreach component [array names diablo_counters_array] {
		array unset diablo_component_array
		array unset diablo_component_array2
		array set diablo_component_array $diablo_counters_array($component)
		array set diablo_component_array2 $diablo_counters_array2($component)
		if {[lsort [array names diablo_component_array]] != [lsort [array names diablo_component_array2]]} {
			set failed_result 1
			break
		} else {
			foreach counter [array names diablo_component_array] {
				if {[lsort $diablo_component_array($counter)] != [lsort $diablo_component_array2($counter)]} {
					set failed_result 1
					break
				}
			}
		}
	}
	if $failed_result {
		fputs "\t failed2"
	} else {
		pputs "\t passed"
	}
}
# foreach component [array names diablo_counters_array] {
# 	array unset component_counters_array
# 	array set component_counters_array $diablo_counters_array($component)
# 	foreach counter [array names component_counters_array] {
# 		array unset counter_array
# 		array set counter_array $component_counters_array($counter)
# 		foreach t {dyn st ts} {
# 			set idx [lsearch -exact $component_counters_array($counter) $t]
# 			set from $idx
# 			incr from -1
# 			if {$idx != -1} {
# 				puts "$component $counter $t \{[lreplace $component_counters_array($counter) $from $idx]\} \\"
# 				break
# 			}
# 		}
# 	}
# }
hputs "\tHTML parser from opsparsers"
set fileId [open [file join $script_path "diablostatus.html"] r]
set HTML_status [read $fileId]
close $fileId
array set diablo_status_array [::mondiablo::parsestatus $HTML_status]
puts -nonewline "\tchecking status parser..."
set components {app app_name app_start_time app_started app_uptime daemon_start_time daemon_uptime group hostname node_id pid plugins user version}
if {[lsort -increasing [array names diablo_status_array]] == $components} {
	foreach {name value} {app {} \
	                        app_name avc_update_daemon \
	                        app_start_time 1365156243.88 \
	                        app_started True \
	                        app_uptime  279725.545277 \
	                        daemon_start_time   1365156243.84 \
	                        daemon_uptime   279725.582623 \
	                        group   avc \
	                        hostname  prod-avc-app2.vega.ironport.com \
	                        node_id   0 \
	                        pid   49328 \
	                        user avc \
	                        version 1.3.0.061} {
		if {$diablo_status_array($name) != $value} {
					fputs "\t failed1"
puts "$name = $diablo_status_array($name) but required $value"
					break
				}
	}
	if {[lsort $diablo_status_array(plugins)] != [lsort {backdoor {port 9950} web {methods {status ft_status log_level reset_counters counter_detail package_stats node_status restart counters} port 11080} zkft {zk_status CONNECTED_STATE service avc_publisher zk_session_timeout 40000}}]} {
		fputs "\t failed3"
	}
pputs "\t passed"
} else {
	fputs "\t failed2"
}
hputs "\tJSON parser from opsparsers"
set fileId [open [file join $script_path "diablostatus.json"] r]
set HTML_status [read $fileId]
close $fileId
array set diablo_status_array2 [::mondiablo::parsestatus $HTML_status]
puts -nonewline "\tchecking status parser..."

set failed_result 0
if {[lsort [array names diablo_status_array]] != [lsort [array names diablo_status_array2]]} {
	fputs "\t failed1"
} else {
	foreach component [array names diablo_status_array] {
		if {[lsort $diablo_status_array($component)] != [lsort $diablo_status_array2($component)]} {
			set failed_result 1
			break
		}
	}
	if $failed_result {
		fputs "\t failed2"
	} else {
		pputs "\t passed"
	}
}
hputs "\tHTML parser from opsparsers"
set fileId [open [file join $script_path "diabloft_status.html"] r]
set HTML_status [read $fileId]
close $fileId
puts -nonewline "\tchecking FT status parser..."
array set diablo_ftstatus_array [::mondiablo::parseftstatus $HTML_status]
set components {app env link node_id node_state pid start_time}
if {[lsort -increasing [array names diablo_ftstatus_array]] == {prod-avc-app1.vega.ironport.com:11080 prod-avc-app2.vega.ironport.com:11080}} {
	array set ftstatus_array1 $diablo_ftstatus_array(prod-avc-app1.vega.ironport.com:11080)
	array set ftstatus_array2 $diablo_ftstatus_array(prod-avc-app2.vega.ironport.com:11080)
	if {[string equal $ftstatus_array1(env) $ftstatus_array2(env)] && [string equal $ftstatus_array2(env) "prod/avc"]} {
		if {[string equal $ftstatus_array1(app) $ftstatus_array2(app)] && [string equal $ftstatus_array2(app) "avc_update_daemon"]} {
			if {[string equal $ftstatus_array1(node_id) $ftstatus_array2(node_id)] && [string equal $ftstatus_array2(node_id) 0]} {
				if {($ftstatus_array1(node_state) == "standby") && ($ftstatus_array2(node_state) == "avc_publisher")} {
					if {($ftstatus_array1(start_time) == [clock scan "Fri Apr  5 03:04:07 2013"]) && ($ftstatus_array2(start_time) == [clock scan "Fri Apr  5 03:04:03 2013"])} {
						if {($ftstatus_array1(pid) == 69150) && ($ftstatus_array2(pid) == 49328)} {
							if {($ftstatus_array1(link) == "prod-avc-app1.vega.ironport.com:11080") && ($ftstatus_array2(link) == "prod-avc-app2.vega.ironport.com:11080")} {
								if {($ftstatus_array1(hostname) == "prod-avc-app1.vega.ironport.com") && ($ftstatus_array2(hostname) == "prod-avc-app2.vega.ironport.com")} {
									pputs "\t passed"
								} else {
									fputs "\t failed9"
								}
							} else {
								fputs "\t failed1"
							}
						} else {
							fputs "\t failed2"
						}
					} else {
						fputs "\t failed3"
						puts "$ftstatus_array1(start_time) != Fri Apr  5 03:04:07 2013 or $ftstatus_array2(start_time) != Fri Apr  5 03:04:03 2013"
					}
				} else {
					fputs "\t failed4"
				}
			} else {
				fputs "\t failed5"
				puts "$ftstatus_array1(node_id) != $ftstatus_array2(node_id)"
			}
		} else {
			fputs "\t failed6"
			puts "$ftstatus_array1(app) != $ftstatus_array2(app)"
		}
	} else {
		fputs "\t failed7"
		puts "$ftstatus_array1(env) != $ftstatus_array2(env)"
	}
} else {
	fputs "\t failed8"
}
hputs "\tJSON parser from opsparsers"
set fileId [open [file join $script_path "diabloft_status.json"] r]
set HTML_status [read $fileId]
close $fileId
puts -nonewline "\tchecking FT status parser..."
array set diablo_ftstatus_array2 [::mondiablo::parseftstatus $HTML_status]


set failed_result 0
if {[lsort [array names diablo_ftstatus_array]] != [lsort [array names diablo_ftstatus_array2]]} {
	fputs "\t failed1"
} else {
	foreach component [array names diablo_ftstatus_array] {
		if {[lsort $diablo_ftstatus_array($component)] != [lsort $diablo_ftstatus_array2($component)]} {
			set failed_result 1
			break
		}
	}
	if $failed_result {
		fputs "\t failed2"
	} else {
		pputs "\t passed"
	}
}
hputs "Checking mondiablo package COMPLETE"
hputs "Checking monoutput"
package require monoutput
puts -nonewline "\tchecking exit codes ..."
if {($EXIT_OK == 0) && ($EXIT_WARNING == 1) && ($EXIT_ERROR == 2) && ($EXIT_UNKNOWN == 3)} {
	pputs "\t passed"
} else {
	fputs "\t failed"
}
puts "\tchecking output format"
set result_array(field1) 1
set result_array(field=2.2) {2.2 "long description of field2.2"}
set result_array(field.5) {.5 "long description of field.5"}
set result_array(fieldBLA) BLA
set result_array(fieldBLA-BLA) {"BLA-BLA" "long description on fieldBLA-BLA"}
set result_array(very_long-field_name6:with:some.special.chars!) 15
puts "\tuse following data:"
puts "\t\t\"field\"=1"
puts "\t\t\"field=2.2\"=2.2 with text description \"long description of field2.2\""
puts "\t\t\"field.5\"=.5 with text description \"long description of field.5\""
puts "\t\t\"fieldBLA\"=BLA"
puts "\t\t\"fieldBLA-BLA\"=BLA-BLA with text description \"long description on fieldBLA-BLA\""
puts "\t\t\"\very_long-field_name6:with:some.special.chars!\"=15"
puts "\t\tmessage for nagios: \"OK\""
puts "---------------------------- Cacti output ------------------------------------------"
::monoutput::cactioutput [array get result_array]
puts "------------------------------------------------------------------------------------"
puts "---------------------------- Nagios output -----------------------------------------"
::monoutput::nagiosoutput -data [array get result_array] "OK"
puts "------------------------------------------------------------------------------------"
puts "---------------- Cacti output with reducing fields names ---------------------------"
::monoutput::cactioutput -reducenames [array get result_array]
puts "------------------------------------------------------------------------------------"
puts "---------------- Nagios output with reducing fields names --------------------------"
::monoutput::nagiosoutput -reducenames -data [array get result_array] "OK"
puts "------------------------------------------------------------------------------------"
puts "------------------------ Nagios simple output --------------------------------------"
::monoutput::nagiosoutput "OK"
puts "------------------------------------------------------------------------------------"
array unset result_array
set result_array(field1) 1
puts "-------------------- Nagios simple output with perfdata ----------------------------"
::monoutput::nagiosoutput -data [array get result_array] "OK"
puts "------------------------------------------------------------------------------------"
set text_list {"text line1" "text line2" "text line3"}
puts "----------------------- Nagios output with long text -------------------------------"
::monoutput::nagiosoutput -text $text_list "OK"
puts "------------------------------------------------------------------------------------"
hputs "Checking monoutput COMPLETE"
# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
