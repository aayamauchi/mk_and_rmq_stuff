namespace eval opsprns {
	variable count 0
	namespace export obj
	variable version 1.0
}
package provide opsprns $::opsprns::version
# args:
# name - name of new object
# ?-initcmd procname   - additional constructor proc (fully-qualified name of any available proc)
# ?-ns nsname   - namespace where should be object created
# ?-var1 val ?-var2 val  - initial variables
# obj X    ;# create object X (namespace ::X,command ::X::X,interp alias ::X)
# obj Y -ns myns  ;# create object myns::Y (namespace ::myns::Y,command ::ns::X::Y, interp alias ::Y)


proc opsprns::obj {name args} {
	if {"$name" eq "new"} {
		set name _obj__[incr ::opsprns::count]
	}
	set newname [eval init $name $args]
	#inconsistency  
	if {[lsearch [info commands] $name] == -1} {
		return [interp alias {} $name {} $newname\::$name]
	} else {
		return $newname\::$name
	}
}

proc ::opsprns::init {name args} {
	set ns {} 
	set initcmd {} 

	if { [set idx [lsearch $args "-ns"]] != -1} {
		set ns ::[string trim [lindex $args [incr idx]] ::]
	}

	set newname $ns\::$name

	namespace eval $newname {} 
	
	foreach {-var val} $args {
		if {${-var} eq "-ns"} {continue}
		if {${-var} eq "-initcmd"} {
			set initcmd $val
			continue
		}
		if {[string index ${-var} 0] eq "-" && [string match {-*} ${-var}]} {
			variable $newname\::[string trimleft ${-var} -] $val
		}
	}

	proc $newname\::[namespace tail $newname] {command args} {
		if {"$command" eq "set" || "$command" eq "unset"} {
			variable [lindex $args 0] 
		}
		eval $command $args  
	}
	#proc $newname\::new args {
	#    eval ::opsprns::obj _obj__[incr ::opsprns::count] -ns [namespace current] $args 
	#}
	proc $newname\::obj {name args} {
		set newobj [eval ::opsprns::obj $name $args]
		[self_] mixin $newobj
		if {[llength [info procs [$newobj namespace current]::init]]} {
			namespace inscope [$newobj namespace current] init
		}
		return $newobj
	}
	proc $newname\::configure {args} {
		foreach {-var val} $args {
			set [namespace current]\::[string trimleft ${-var} -] $val
		}
	}
	proc $newname\::cget {-var} {
		if {[info exists [namespace current]\::[string trimleft ${-var} -]]} {
			return [set [namespace current]\::[string trimleft ${-var} -]]
		} else {
			return -code error "Option ${-var} does not exist"
		}
	}
	proc $newname\::info_ {cmd args} {
		switch -- $cmd {
			parent  {return [namespace parent]::[namespace tail [namespace parent]]}
			childs { set l {}
				foreach chld [namespace children] {
					lappend l [namespace tail $chld]
				}
				return $l
			}
			vars  {  set l {}
				foreach var [::info vars [namespace current]::*] {
					lappend l [namespace tail $var]
				}
				return $l
			}
			default {eval ::info $cmd $args}
		}
	}
	proc $newname\::instvar args {
		foreach var $args {
			uplevel 1 variable $var 
		}
	} 
	proc $newname\::instproc args {
		variable expprocs
		eval proc $args
		set expprocs([lindex $args 0]) 1 
		return
	}
	proc $newname\::my_ args {
		eval [self_] $args 
	}
	proc $newname\::self_ {} {
		return [namespace current]::[namespace tail [namespace current]] 
	}
	proc $newname\::destroy {} {
		set dispcmd [lindex [info level -1] 0]
		catch { interp alias {} [namespace qualifiers $dispcmd] {} }
		catch { rename [namespace qualifiers $dispcmd] {} }
		namespace delete [namespace current]
		return
	}
	proc $newname\::mixin {obj} {
		variable privvars
		variable expprocs
		if {![string equal [info commands $obj] "$obj"]} {
			return -code error "Target object $obj not exist"
		}
		set currns [namespace current] 
		set targns [$obj namespace current]
		foreach cmd [info procs ${currns}::*] {
			set cmd [namespace tail $cmd]
			if {![info exists expprocs($cmd)]} {continue}
			set pargs ""
			foreach arg [info args $cmd] {
				if {[info default $cmd $arg defval]} {
					append pargs "\{$arg \{$defval\}\} "
				} else {
					append pargs "$arg "
				}
			}
			eval proc $targns\::$cmd [list $pargs] [list [info body $cmd]]
		}
		foreach var [info vars ${currns}::*] {
			set var [namespace tail $var]
			if {[info exists privvars($var)]} {continue}
			variable $var
			if {[array exists $var]} {
				upvar 0 $var arr
				variable $targns\::$var
				array set $targns\::$var [array get arr]
			} elseif {[exists $var]} {
				variable $targns\::$var [set $var]
			} 
		}
		return
	}
	proc $newname\::newchild {objnew args} {
		if {[info procs $objnew] eq "$objnew"} {
			return -code error "Child $objnew (proc) already exist"
		}
		set obj [eval ::opsprns::init $objnew -ns [namespace current] $args]
		proc [namespace current]::$objnew args {
			set mycmd [lindex [info level 0] 0]
			eval $mycmd\::[namespace tail $mycmd] $args           
		}
		return $obj
	}
	proc $newname\::exists {var} {
		variable $var
		if {[array exists $var]} {
			return 1
		}
		return [info exists $var]
	}
	proc $newname\::privvar {args} {
		variable privvars
		foreach var $args {
			set privvars($var) ""
		}
	}
	
	if {[llength [info commands [lindex $initcmd 0]]]} {
		eval proc $newname\::init__ args [list [info body [lindex $initcmd 0]]]
		#execute additional init proc
		eval $newname\::init__ [lrange $initcmd 1 end]

	}
	
	return $newname

}
# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
