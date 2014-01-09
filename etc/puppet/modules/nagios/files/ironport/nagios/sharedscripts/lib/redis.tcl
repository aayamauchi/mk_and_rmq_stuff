# Tcl clinet library - used by test-redis.tcl script for now
# Copyright (C) 2009 Salvatore Sanfilippo
# Released under the BSD license like Redis itself
# http://download.redis.io/redis-stable/tests/support/redis.tcl
# backported to Tcl 8.4 by Maksym Tiurin 
#
# Example usage:
#
# set r [redis 127.0.0.1 6379]
# $r lpush mylist foo
# $r lpush mylist bar
# $r lrange mylist 0 -1
# $r close
#
# Non blocking usage example:
#
# proc handlePong {r type reply} {
#     puts "PONG $type '$reply'"
#     if {$reply ne "PONG"} {
#         $r ping [list handlePong]
#     }
# }
# 
# set r [redis]
# $r blocking 0
# $r get fo [list handlePong]
#
# vwait forever

package require Tcl 8.4
package provide opsredis 0.1

namespace eval opsredis {}
set ::opsredis::id 0
array set ::opsredis::fd {}
array set ::opsredis::blocking {}
array set ::opsredis::deferred {}
array set ::opsredis::callback {}
array set ::opsredis::state {} ;# State in non-blocking reply reading
array set ::opsredis::statestack {} ;# Stack of states, for nested mbulks

proc redis {{server 127.0.0.1} {port 6379} {defer 0}} {
	set fd [socket $server $port]
	fconfigure $fd -translation binary
	set id [incr ::opsredis::id]
	set ::opsredis::fd($id) $fd
	set ::opsredis::blocking($id) 1
	set ::opsredis::deferred($id) $defer
	::opsredis::redis_reset_state $id
	interp alias {} ::opsredis::redisHandle$id {} ::opsredis::__dispatch__ $id
}

proc ::opsredis::__dispatch__ {id method args} {
	set fd $::opsredis::fd($id)
	set blocking $::opsredis::blocking($id)
	set deferred $::opsredis::deferred($id)
	if {$blocking == 0} {
		if {[llength $args] == 0} {
			error "Please provide a callback in non-blocking mode"
		}
		set callback [lindex $args end]
		set args [lrange $args 0 end-1]
	}
	if {[info command ::opsredis::__method__$method] eq {}} {
		set cmd "*[expr {[llength $args]+1}]\r\n"
		append cmd "$[string length $method]\r\n$method\r\n"
		foreach a $args {
			append cmd "$[string length $a]\r\n$a\r\n"
		}
		::opsredis::redis_write $fd $cmd
		flush $fd

		if {!$deferred} {
			if {$blocking} {
				::opsredis::redis_read_reply $fd
			} else {
				# Every well formed reply read will pop an element from this
				# list and use it as a callback. So pipelining is supported
				# in non blocking mode.
				lappend ::opsredis::callback($id) $callback
				fileevent $fd readable [list ::opsredis::redis_readable $fd $id]
			}
		}
	} else {
		uplevel 1 [list ::opsredis::__method__$method $id $fd] $args
	}
}

proc ::opsredis::__method__blocking {id fd val} {
	set ::opsredis::blocking($id) $val
	fconfigure $fd -blocking $val
}

proc ::opsredis::__method__read {id fd} {
	::opsredis::redis_read_reply $fd
}

proc ::opsredis::__method__write {id fd buf} {
	::opsredis::redis_write $fd $buf
}

proc ::opsredis::__method__flush {id fd} {
	flush $fd
}

proc ::opsredis::__method__close {id fd} {
	catch {close $fd}
	catch {unset ::opsredis::fd($id)}
	catch {unset ::opsredis::blocking($id)}
	catch {unset ::opsredis::state($id)}
	catch {unset ::opsredis::statestack($id)}
	catch {unset ::opsredis::callback($id)}
	catch {interp alias {} ::opsredis::redisHandle$id {}}
}

proc ::opsredis::__method__channel {id fd} {
	return $fd
}

proc ::opsredis::redis_write {fd buf} {
	puts -nonewline $fd $buf
}

proc ::opsredis::redis_writenl {fd buf} {
	redis_write $fd $buf
	redis_write $fd "\r\n"
	flush $fd
}

proc ::opsredis::redis_readnl {fd len} {
	set buf [read $fd $len]
	read $fd 2 ; # discard CR LF
	return $buf
}

proc ::opsredis::redis_bulk_read {fd} {
	set count [redis_read_line $fd]
	if {$count == -1} return {}
	set buf [redis_readnl $fd $count]
	return $buf
}

proc ::opsredis::redis_multi_bulk_read fd {
	set count [redis_read_line $fd]
	if {$count == -1} return {}
	set l {}
	set err {}
	for {set i 0} {$i < $count} {incr i} {
		if {[catch {
			lappend l [redis_read_reply $fd]
		} e] && $err eq {}} {
			set err $e
		}
	}
	if {$err ne {}} {return -code error $err}
	return $l
}

proc ::opsredis::redis_read_line fd {
	string trim [gets $fd]
}

proc ::opsredis::redis_read_reply fd {
	set type [read $fd 1]
	switch -exact -- $type {
		: -
		+ {redis_read_line $fd}
		- {return -code error [redis_read_line $fd]}
		$ {redis_bulk_read $fd}
		* {redis_multi_bulk_read $fd}
		default {return -code error "Bad protocol, '$type' as reply type byte"}
	}
}

proc ::opsredis::redis_reset_state id {
	set ::opsredis::state($id) {buf {} mbulk -1 bulk -1 reply {}}
	set ::opsredis::statestack($id) {}
}

proc ::opsredis::redis_call_callback {id type reply} {
	set cb [lindex $::opsredis::callback($id) 0]
	set ::opsredis::callback($id) [lrange $::opsredis::callback($id) 1 end]
	uplevel #0 $cb [list ::opsredis::redisHandle$id $type $reply]
	::opsredis::redis_reset_state $id
}

# Read a reply in non-blocking mode.
proc ::opsredis::redis_readable {fd id} {
	if {[eof $fd]} {
		redis_call_callback $id eof {}
		::opsredis::__method__close $id $fd
		return
	}
	array unset opsredis_state_array
	array set opsredis_state_array $::opsredis::state($id)
	if {$opsredis_state_array(bulk) == -1} {
		set line [gets $fd]
		if {$line eq {}} return ;# No complete line available, return
		switch -exact -- [string index $line 0] {
			: -
			+ {redis_call_callback $id reply [string range $line 1 end-1]}
			- {redis_call_callback $id err [string range $line 1 end-1]}
			$ {
				set opsredis_state_array(bulk) \
				  [expr [string range $line 1 end-1]+2]
				if {$opsredis_state_array(bulk) == 1} {
					# We got a $-1, hack the state to play well with this.
					set opsredis_state_array(bulk) 2
					set opsredis_state_array(buf) "\r\n"
					set ::opsredis::state($id) [array get opsredis_state_array]
					::opsredis::redis_readable $fd $id
				}
			}
			* {
				set opsredis_state_array(mbulk) [string range $line 1 end-1]
				# Handle *-1
				if {$opsredis_state_array(mbulk) == -1} {
					set ::opsredis::state($id) [array get opsredis_state_array]
					redis_call_callback $id reply {}
				}
			}
			default {
				redis_call_callback $id err \
				  "Bad protocol, $type as reply type byte"
			}
		}
	} else {
		set totlen $opsredis_state_array(bulk)
		set buflen [string length $opsredis_state_array(buf)]
		set toread [expr {$totlen-$buflen}]
		set data [read $fd $toread]
		set nread [string length $data]
		append opsredis_state_array(buf) $data
		# Check if we read a complete bulk reply
		if {[string length $opsredis_state_array(buf)] ==
		    $opsredis_state_array(bulk)} {
			if {$opsredis_state_array(mbulk) == -1} {
				set ::opsredis::state($id) [array get opsredis_state_array]
				redis_call_callback $id reply \
				  [string range $opsredis_state_array(buf) 0 end-2]
			} else {
				lappend opsredis_state_array(reply) [string range $opsredis_state_array(buf) 0 end-2]
				incr opsredis_state_array(mbulk) -1
				set opsredis_state_array(bulk) -1
				set ::opsredis::state($id) [array get opsredis_state_array]
				if {$opsredis_state_array(mbulk) == 0} {
					redis_call_callback $id reply \
					  $opsredis_state_array(reply)
				}
			}
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
