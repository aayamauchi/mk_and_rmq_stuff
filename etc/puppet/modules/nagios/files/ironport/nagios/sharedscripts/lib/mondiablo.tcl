lappend auto_path [file dirname [info script]]

namespace eval ::mondiablo {
	namespace export mondiablo
	variable version 0.2
}

package provide mondiablo $::mondiablo::version

package require opsparsers
package require opsprns
# in this package lsearch -all was used, so it works only in Tcl >= 8.4
package require Tcl 8.4

# diablo provides JSON with MD5 checksum
# so we need md5 function for calculating hash
if [catch {package require md5} res] {
	# md5 from tcllib does not exists - use pure Tcl MD5 function
	# MD5 in Tcl was written by Don Libes <libes@nist.gov>, July 1999
	# Version 1.2.0
	# http://equi4.com/md5/migmd5.tcl
	namespace eval ::md5 {
	}
	#
	# We just define the body of md5pure::md5 here; later we
	# regsub to inline a few function calls for speed
	#
	set ::md5::md5body {
		#
		# 3.1 Step 1. Append Padding Bits
		#
		set msgLen [string length $msg]
		set padLen [expr {56 - $msgLen%64}]
		if {$msgLen % 64 > 56} {
			incr padLen 64
		}
		# pad even if no padding required
		if {$padLen == 0} {
			incr padLen 64
		}
		# append single 1b followed by 0b's
		append msg [binary format "a$padLen" \200]
		#
		# 3.2 Step 2. Append Length
		#
		# RFC doesn't say whether to use little- or big-endian
		# code demonstrates little-endian
		# This step limits our input to size 2^32b or 2^24B
		append msg [binary format "i1i1" [expr {8*$msgLen}] 0]
		#
		# 3.3 Step 3. Initialize MD Buffer
		#
		set A [expr 0x67452301]
		set B [expr 0xefcdab89]
		set C [expr 0x98badcfe]
		set D [expr 0x10325476]
		#
		# 3.4 Step 4. Process Message in 16-Word Blocks
		#
		# process each 16-word block
		# RFC doesn't say whether to use little- or big-endian
		# code says little-endian
		binary scan $msg i* blocks
		set len [llength $blocks]
		# loop over the message taking 16 blocks at a time
		foreach {X0 X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15} $blocks {
			# Save A as AA, B as BB, C as CC, and D as DD.
			set AA $A
			set BB $B
			set CC $C
			set DD $D
			# Round 1.
			# Let [abcd k s i] denote the operation
			#      a = b + ((a + F(b,c,d) + X[k] + T[i]) <<< s).
			# [ABCD  0  7  1]  [DABC  1 12  2]  [CDAB  2 17  3]  [BCDA  3 22  4]
			set A [expr {$B + [<<< [expr {$A + [F $B $C $D] + $X0  + $T01}]  7]}]
			set D [expr {$A + [<<< [expr {$D + [F $A $B $C] + $X1  + $T02}] 12]}]
			set C [expr {$D + [<<< [expr {$C + [F $D $A $B] + $X2  + $T03}] 17]}]
			set B [expr {$C + [<<< [expr {$B + [F $C $D $A] + $X3  + $T04}] 22]}]
			# [ABCD  4  7  5]  [DABC  5 12  6]  [CDAB  6 17  7]  [BCDA  7 22  8]
			set A [expr {$B + [<<< [expr {$A + [F $B $C $D] + $X4  + $T05}]  7]}]
			set D [expr {$A + [<<< [expr {$D + [F $A $B $C] + $X5  + $T06}] 12]}]
			set C [expr {$D + [<<< [expr {$C + [F $D $A $B] + $X6  + $T07}] 17]}]
			set B [expr {$C + [<<< [expr {$B + [F $C $D $A] + $X7  + $T08}] 22]}]
			# [ABCD  8  7  9]  [DABC  9 12 10]  [CDAB 10 17 11]  [BCDA 11 22 12]
			set A [expr {$B + [<<< [expr {$A + [F $B $C $D] + $X8  + $T09}]  7]}]
			set D [expr {$A + [<<< [expr {$D + [F $A $B $C] + $X9  + $T10}] 12]}]
			set C [expr {$D + [<<< [expr {$C + [F $D $A $B] + $X10 + $T11}] 17]}]
			set B [expr {$C + [<<< [expr {$B + [F $C $D $A] + $X11 + $T12}] 22]}]
			# [ABCD 12  7 13]  [DABC 13 12 14]  [CDAB 14 17 15]  [BCDA 15 22 16]
			set A [expr {$B + [<<< [expr {$A + [F $B $C $D] + $X12 + $T13}]  7]}]
			set D [expr {$A + [<<< [expr {$D + [F $A $B $C] + $X13 + $T14}] 12]}]
			set C [expr {$D + [<<< [expr {$C + [F $D $A $B] + $X14 + $T15}] 17]}]
			set B [expr {$C + [<<< [expr {$B + [F $C $D $A] + $X15 + $T16}] 22]}]
			# Round 2.
			# Let [abcd k s i] denote the operation
			#      a = b + ((a + G(b,c,d) + X[k] + T[i]) <<< s).
			# Do the following 16 operations.
			# [ABCD  1  5 17]  [DABC  6  9 18]  [CDAB 11 14 19]  [BCDA  0 20 20]
			set A [expr {$B + [<<< [expr {$A + [G $B $C $D] + $X1  + $T17}]  5]}]
			set D [expr {$A + [<<< [expr {$D + [G $A $B $C] + $X6  + $T18}]  9]}]
			set C [expr {$D + [<<< [expr {$C + [G $D $A $B] + $X11 + $T19}] 14]}]
			set B [expr {$C + [<<< [expr {$B + [G $C $D $A] + $X0  + $T20}] 20]}]
			# [ABCD  5  5 21]  [DABC 10  9 22]  [CDAB 15 14 23]  [BCDA  4 20 24]
			set A [expr {$B + [<<< [expr {$A + [G $B $C $D] + $X5  + $T21}]  5]}]
			set D [expr {$A + [<<< [expr {$D + [G $A $B $C] + $X10 + $T22}]  9]}]
			set C [expr {$D + [<<< [expr {$C + [G $D $A $B] + $X15 + $T23}] 14]}]
			set B [expr {$C + [<<< [expr {$B + [G $C $D $A] + $X4  + $T24}] 20]}]
			# [ABCD  9  5 25]  [DABC 14  9 26]  [CDAB  3 14 27]  [BCDA  8 20 28]
			set A [expr {$B + [<<< [expr {$A + [G $B $C $D] + $X9  + $T25}]  5]}]
			set D [expr {$A + [<<< [expr {$D + [G $A $B $C] + $X14 + $T26}]  9]}]
			set C [expr {$D + [<<< [expr {$C + [G $D $A $B] + $X3  + $T27}] 14]}]
			set B [expr {$C + [<<< [expr {$B + [G $C $D $A] + $X8  + $T28}] 20]}]
			# [ABCD 13  5 29]  [DABC  2  9 30]  [CDAB  7 14 31]  [BCDA 12 20 32]
			set A [expr {$B + [<<< [expr {$A + [G $B $C $D] + $X13 + $T29}]  5]}]
			set D [expr {$A + [<<< [expr {$D + [G $A $B $C] + $X2  + $T30}]  9]}]
			set C [expr {$D + [<<< [expr {$C + [G $D $A $B] + $X7  + $T31}] 14]}]
			set B [expr {$C + [<<< [expr {$B + [G $C $D $A] + $X12 + $T32}] 20]}]
			# Round 3.
			# Let [abcd k s t] [sic] denote the operation
			#     a = b + ((a + H(b,c,d) + X[k] + T[i]) <<< s).
			# Do the following 16 operations.
			# [ABCD  5  4 33]  [DABC  8 11 34]  [CDAB 11 16 35]  [BCDA 14 23 36]
			set A [expr {$B + [<<< [expr {$A + [H $B $C $D] + $X5  + $T33}]  4]}]
			set D [expr {$A + [<<< [expr {$D + [H $A $B $C] + $X8  + $T34}] 11]}]
			set C [expr {$D + [<<< [expr {$C + [H $D $A $B] + $X11 + $T35}] 16]}]
			set B [expr {$C + [<<< [expr {$B + [H $C $D $A] + $X14 + $T36}] 23]}]
			# [ABCD  1  4 37]  [DABC  4 11 38]  [CDAB  7 16 39]  [BCDA 10 23 40]
			set A [expr {$B + [<<< [expr {$A + [H $B $C $D] + $X1  + $T37}]  4]}]
			set D [expr {$A + [<<< [expr {$D + [H $A $B $C] + $X4  + $T38}] 11]}]
			set C [expr {$D + [<<< [expr {$C + [H $D $A $B] + $X7  + $T39}] 16]}]
			set B [expr {$C + [<<< [expr {$B + [H $C $D $A] + $X10 + $T40}] 23]}]
			# [ABCD 13  4 41]  [DABC  0 11 42]  [CDAB  3 16 43]  [BCDA  6 23 44]
			set A [expr {$B + [<<< [expr {$A + [H $B $C $D] + $X13 + $T41}]  4]}]
			set D [expr {$A + [<<< [expr {$D + [H $A $B $C] + $X0  + $T42}] 11]}]
			set C [expr {$D + [<<< [expr {$C + [H $D $A $B] + $X3  + $T43}] 16]}]
			set B [expr {$C + [<<< [expr {$B + [H $C $D $A] + $X6  + $T44}] 23]}]
			# [ABCD  9  4 45]  [DABC 12 11 46]  [CDAB 15 16 47]  [BCDA  2 23 48]
			set A [expr {$B + [<<< [expr {$A + [H $B $C $D] + $X9  + $T45}]  4]}]
			set D [expr {$A + [<<< [expr {$D + [H $A $B $C] + $X12 + $T46}] 11]}]
			set C [expr {$D + [<<< [expr {$C + [H $D $A $B] + $X15 + $T47}] 16]}]
			set B [expr {$C + [<<< [expr {$B + [H $C $D $A] + $X2  + $T48}] 23]}]
			# Round 4.
			# Let [abcd k s t] [sic] denote the operation
			#     a = b + ((a + I(b,c,d) + X[k] + T[i]) <<< s).
			# Do the following 16 operations.
			# [ABCD  0  6 49]  [DABC  7 10 50]  [CDAB 14 15 51]  [BCDA  5 21 52]
			set A [expr {$B + [<<< [expr {$A + [I $B $C $D] + $X0  + $T49}]  6]}]
			set D [expr {$A + [<<< [expr {$D + [I $A $B $C] + $X7  + $T50}] 10]}]
			set C [expr {$D + [<<< [expr {$C + [I $D $A $B] + $X14 + $T51}] 15]}]
			set B [expr {$C + [<<< [expr {$B + [I $C $D $A] + $X5  + $T52}] 21]}]
			# [ABCD 12  6 53]  [DABC  3 10 54]  [CDAB 10 15 55]  [BCDA  1 21 56]
			set A [expr {$B + [<<< [expr {$A + [I $B $C $D] + $X12 + $T53}]  6]}]
			set D [expr {$A + [<<< [expr {$D + [I $A $B $C] + $X3  + $T54}] 10]}]
			set C [expr {$D + [<<< [expr {$C + [I $D $A $B] + $X10 + $T55}] 15]}]
			set B [expr {$C + [<<< [expr {$B + [I $C $D $A] + $X1  + $T56}] 21]}]
			# [ABCD  8  6 57]  [DABC 15 10 58]  [CDAB  6 15 59]  [BCDA 13 21 60]
			set A [expr {$B + [<<< [expr {$A + [I $B $C $D] + $X8  + $T57}]  6]}]
			set D [expr {$A + [<<< [expr {$D + [I $A $B $C] + $X15 + $T58}] 10]}]
			set C [expr {$D + [<<< [expr {$C + [I $D $A $B] + $X6  + $T59}] 15]}]
			set B [expr {$C + [<<< [expr {$B + [I $C $D $A] + $X13 + $T60}] 21]}]
			# [ABCD  4  6 61]  [DABC 11 10 62]  [CDAB  2 15 63]  [BCDA  9 21 64]
			set A [expr {$B + [<<< [expr {$A + [I $B $C $D] + $X4  + $T61}]  6]}]
			set D [expr {$A + [<<< [expr {$D + [I $A $B $C] + $X11 + $T62}] 10]}]
			set C [expr {$D + [<<< [expr {$C + [I $D $A $B] + $X2  + $T63}] 15]}]
			set B [expr {$C + [<<< [expr {$B + [I $C $D $A] + $X9  + $T64}] 21]}]
			# Then perform the following additions. (That is increment each
			#   of the four registers by the value it had before this block
			#   was started.)
			incr A $AA
			incr B $BB
			incr C $CC
			incr D $DD
		}
		# 3.5 Step 5. Output
		# ... begin with the low-order byte of A, and end with the high-order byte
		# of D.
		return [bytes $A][bytes $B][bytes $C][bytes $D]
	}
	#
	# Here we inline/regsub the functions F, G, H, I and <<< 
	#
	namespace eval ::md5 {
		#proc md5pure::F {x y z} {expr {(($x & $y) | ((~$x) & $z))}}
		regsub -all {\[ *F +(\$.) +(\$.) +(\$.) *\]} $md5body {((\1 \& \2) | ((~\1) \& \3))} md5body
		#proc md5pure::G {x y z} {expr {(($x & $z) | ($y & (~$z)))}}
		regsub -all {\[ *G +(\$.) +(\$.) +(\$.) *\]} $md5body {((\1 \& \3) | (\2 \& (~\3)))} md5body
		#proc md5pure::H {x y z} {expr {$x ^ $y ^ $z}}
		regsub -all {\[ *H +(\$.) +(\$.) +(\$.) *\]} $md5body {(\1 ^ \2 ^ \3)} md5body
		#proc md5pure::I {x y z} {expr {$y ^ ($x | (~$z))}}
		regsub -all {\[ *I +(\$.) +(\$.) +(\$.) *\]} $md5body {(\2 ^ (\1 | (~\3)))} md5body
		# bitwise left-rotate
		if 0 {
			proc md5pure::<<< {x i} {
				# This works by bitwise-ORing together right piece and left
				# piece so that the (original) right piece becomes the left
				# piece and vice versa.
				#
				# The (original) right piece is a simple left shift.
				# The (original) left piece should be a simple right shift
				# but Tcl does sign extension on right shifts so we
				# shift it 1 bit, mask off the sign, and finally shift
				# it the rest of the way.
				expr {($x << $i) | ((($x >> 1) & 0x7fffffff) >> (31-$i))}
			}
		}
		# inline <<<
		regsub -all {\[ *<<< +\[ *expr +({[^\}]*})\] +([0-9]+) *\]} $md5body {(([set x [expr \1]] << \2) |  ((($x >> 1) \& 0x7fffffff) >> (31-\2)))} md5body
		# inline the values of T
		set map {}
		foreach \
			tName {
			T01 T02 T03 T04 T05 T06 T07 T08 T09 T10 
			T11 T12 T13 T14 T15 T16 T17 T18 T19 T20 
			T21 T22 T23 T24 T25 T26 T27 T28 T29 T30 
			T31 T32 T33 T34 T35 T36 T37 T38 T39 T40 
			T41 T42 T43 T44 T45 T46 T47 T48 T49 T50 
			T51 T52 T53 T54 T55 T56 T57 T58 T59 T60 
			T61 T62 T63 T64 } \
			tVal {
				0xd76aa478 0xe8c7b756 0x242070db 0xc1bdceee
				0xf57c0faf 0x4787c62a 0xa8304613 0xfd469501
				0x698098d8 0x8b44f7af 0xffff5bb1 0x895cd7be
				0x6b901122 0xfd987193 0xa679438e 0x49b40821

				0xf61e2562 0xc040b340 0x265e5a51 0xe9b6c7aa
				0xd62f105d 0x2441453  0xd8a1e681 0xe7d3fbc8
				0x21e1cde6 0xc33707d6 0xf4d50d87 0x455a14ed
				0xa9e3e905 0xfcefa3f8 0x676f02d9 0x8d2a4c8a

				0xfffa3942 0x8771f681 0x6d9d6122 0xfde5380c
				0xa4beea44 0x4bdecfa9 0xf6bb4b60 0xbebfbc70
				0x289b7ec6 0xeaa127fa 0xd4ef3085 0x4881d05
				0xd9d4d039 0xe6db99e5 0x1fa27cf8 0xc4ac5665

				0xf4292244 0x432aff97 0xab9423a7 0xfc93a039
				0x655b59c3 0x8f0ccc92 0xffeff47d 0x85845dd1
				0x6fa87e4f 0xfe2ce6e0 0xa3014314 0x4e0811a1
				0xf7537e82 0xbd3af235 0x2ad7d2bb 0xeb86d391
			} {
				lappend map \$$tName $tVal
			}
		set md5body [string map $map $md5body]
		# Finally, define the proc
		proc md5hex {msg} $md5body
		# unset auxiliary variables
		unset md5body tName tVal map
	}
	proc ::md5::byte0 {i} {expr {0xff & $i}}
	proc ::md5::byte1 {i} {expr {(0xff00 & $i) >> 8}}
	proc ::md5::byte2 {i} {expr {(0xff0000 & $i) >> 16}}
	proc ::md5::byte3 {i} {expr {((0xff000000 & $i) >> 24) & 0xff}}
	proc ::md5::bytes {i} {
		format %0.2x%0.2x%0.2x%0.2x [byte0 $i] [byte1 $i] [byte2 $i] [byte3 $i]
	}
} else {
	proc ::md5::md5hex {msg} {
		return [::md5::md5 -hex $msg]
	}
}
# ::mondiablo::_checkmd5 -- check JSON md5
#
# Check JSONs MD5 if it present
#
# Arguments:
# data      - string with JSON (with or without MD5).
#
# Side Effects:
# None.
#
# Results:
# string with JSON without MD5
# error when MD5 check was failed
proc ::mondiablo::_checkmd5 {data} {
	if [regexp -expanded -nocase {^[\da-f]{32}\n\{} $data] {
		# md5 checksum present - check it
		# first line is MD5
		set MD5_checksum [lindex [split $data "\n"] 0]
		# other is JSON
		set JSON [join [lrange [split $data "\n"] 1 end] "\n"]
		if ![string equal -nocase [::md5::md5hex $JSON] $MD5_checksum] {
			# bad checksum of JSON
			return -code error "MD5 verification failed"
		}
		return $JSON
	} else {
		return $data
	}
}
# ::mondiablo::parsecounters -- parse diablo counters web page
#
# Parse html or JSON with counters from diablo web plugin and return
# formated result. This function requires Tcl 8.4 and later.
#
# Arguments:
# html  - string with html page or JSON
#
# Side Effects:
# None.
#
# Results:
# list with arrays as list which contains counters with values. For ts
# (timestamp) counters values are converted to unixtime format.
# Format of returned structure is:
# { {section1 {counter1 {type counter1_type "current value" counter1_value ...}
#              counter2 {type counter2_type "current value" counter2_value ...}
#              ....}
#   {section2 {counter1 {type counter1_type "current value" counter1_value ...}
#              counter2 {type counter2_type "current value" counter2_value ...}
#              ....}
#   ...
# }
# where type one of {st dyn ts}
# Error when: 
#  converted from JSON array has incorrect format ("array verification failed")
#  MD5 verification was unsuccessful ("MD5 verification failed")
#  JSON to array conversion was unsuccessful
proc ::mondiablo::parsecounters {html} {
	# create prns class with variables
	opsprns::obj parser -counter 0 -counter_name "" -counter_value "" -multiline_counter 0 -counters_list {}
	# diablo counters page parser (parser class method)
	parser instproc counters_parser {tag state props body} {
		# get access to class variables
		instvar counter
		instvar counter_name
		instvar counter_value
		instvar multiline_counter
		instvar counters_list
		# state is empty when tag is open tag
		if {$state == ""} {
			# find counters in <li class="counter_item"> <span class="counter_key"> <span class="counter_value">
			if {($tag == "li") && ($props == {class="counter_item"})} {
				# new counters block
				set counter 1
				set counter_name ""
				return
			}
			if {$counter && ($tag == "span") && ($props == {class="counter_key"})} {
				# new counter block
				set counter_name [string trim $body]
				return
			}
			if {($counter_name != "") && ($tag == "span") && [regexp {class="counter_(rate|value|timestamp)"} $props]} {
				# counter
				if ![regexp -expanded {^[\s\n]*$} $body] {
					# counter without link to details
					lappend counters_list "$counter_name $body"
					set multiline_counter 0
				} else {
					set multiline_counter 1
				}
				return
			}
			if {$multiline_counter && ($tag == "a") && [regexp {href=".*/counter_detail\?.*"} $props]} {
				# counter with link to details
				lappend counters_list "$counter_name [string trim $body { 
}]"
				set multiline_counter 0
			}
		} else {
			# close tag
			if {$tag == "li"} {
				set counter 0
				set counter_name ""
			}
		}
	}
	parser instproc get_counters {} {
		# get access to class variables
		instvar counters_list
		array unset counters_array
		while {[llength $counters_list] > 0} {
			if [regexp -expanded {^(\w+):(\w+):(st|dyn|ts)\s+.*$} [lindex $counters_list 0] match component component_counter counter_type] {
				# counter string - find all records for this counter
				set counter_idxs [lsearch -regexp -all $counters_list "^$component:$component_counter:"]
				array unset counter_array
				set counter_array(type) $counter_type
				foreach counter_idx [lsort -integer -decreasing $counter_idxs] {
					if [regexp -expanded "^$component:$component_counter:$counter_type\\s+(\[^:\]+):\\s+(.*)\$" [lindex $counters_list $counter_idx]  match value_type value] {
						if {$value_type == "ts"} {
							# convert it to unixtime and rename 'ts' to 'current value'
							set counter_array(current\ value) [clock scan $value]
						} else {
							set counter_array($value_type) $value
						}
					}
					set counters_list [lreplace $counters_list $counter_idx $counter_idx]
				}
				if {[array names counters_array -exact $component] == {}} {
					# new component
					set counters_array($component) [list $component_counter [array get counter_array]]
				} else {
					# new counter in component
					lappend counters_array($component) $component_counter [array get counter_array]
				}
			} else {
				# bad string
				set counters_list [lreplace $counters_list 0 0]
			}
		}
		return [array get counters_array]
	}
	# check input data type
	if [regexp -expanded -nocase {.*<html>.*<head>.*</head>.*<body>.*</body>.*</html>.*} $html] {
		# html page with counters
		::opsparsers::HMparse_html $html {parser counters_parser}
		array set result [parser get_counters]
		# destroy object
		parser destroy
	} else {
		# JSON
		set JSONarray_list [::opsparsers::json2array [_checkmd5 $html]]
		# correct array must be contain even elements
		if [expr {([llength $JSONarray_list] % 2) != 0}] {
			# bad array
			return -code error "array verification failed"
		}
		array set JSONarray $JSONarray_list
		unset JSONarray_list
		array set result {}
		# rename component:counter to counter
		foreach component [array names JSONarray] {
			array unset counters_array
			array unset new_counters_array
			array set counters_array $JSONarray($component)
			foreach counter [array names counters_array] {
				regexp "^$component:(.*)$" $counter res new_counter
				# replace counter types: DynamicCounter -> dyn, StaticCounter -> st, Timestamp -> ts
				set counter_string $counters_array($counter)
				foreach {old new} {DynamicCounter dyn StaticCounter st Timestamp ts} {
					regsub -- "type\\s+$old" $counter_string "type $new" counter_string
				}
				set new_counters_array($new_counter) $counter_string
			}
			set result($component) [array get new_counters_array]
		}
	}
	return [array get result]
}
# ::mondiablo::parsestatus -- parse diablo status web page
#
# Parse html or JSON with status from diablo web plugin and return
# formated result.
#
# Arguments:
# html  - string with html page or JSON
#
# Side Effects:
# None.
#
# Results:
# list with arrays as list which contains node status values.
# Format of returned structure is:
# { key1 value1
#   key2 value2
#   ....
# }
# Error when: 
#  converted from JSON array has incorrect format ("array verification failed")
#  MD5 verification was unsuccessful ("MD5 verification failed")
#  JSON to array conversion was unsuccessful
proc ::mondiablo::parsestatus {html} {
	# create prns class with variables
	opsprns::obj parser -status 0 -status_item 0 -status_name "" -status_list {}
	# diablo counters page parser (parser class method)
	parser instproc status_parser {tag state props body} {
		# get access to class variables
		instvar status
		instvar status_item
		instvar status_name
		instvar status_list
		# state is empty when tag is open tag
		if {$state == ""} {
			# find <table class="status_dict">  <tr><td>key</td><td>value</td></tr>
			if {($tag == "table") && ($props == {class="status_dict"})} {
				# start status table
				set status 1
				set status_item 0
				set status_name ""
				return
			}
			if {$status && !$status_item && ($tag == "tr")} {
				# start status item
				set status_item 1
			}
			if {$status && $status_item && ($tag == "td")} {
				if {$status_name == ""} {
					# status item name
					set status_name [string trim $body " 
"]
				} else {
					# status item value
					lappend status_list $status_name [string trim $body " 
"]
				}
			}
		} else {
			# close tag
			if {$tag == "tr"} {
				set status_name ""
				set status_item 0
			} elseif {$tag == "table"} {
				set status 0
			}
		}
	}
	parser instproc get_status {} {
		# get access to class variables
		instvar status_list
		set result {}
		# unmap html sequences
		foreach line $status_list {
			lappend result [::opsparsers::unmap_html $line]
		}
		array set result_array $result
		unset result
		foreach key [array names result_array] {
			if {$key == "plugins"} {
				# convert plugins JSON to array
				set result_array($key) [::opsparsers::json2array $result_array($key)]
			}
			if {$result_array($key) == "{}"} {
				# convert {} value to empty
				set result_array($key) {}
			}
		}
		return [array get result_array]
	}
	# check input data type
	if [regexp -expanded -nocase {.*<html>.*<head>.*</head>.*<body>.*</body>.*</html>.*} $html] {
		# html page with counters
		::opsparsers::HMparse_html $html {parser status_parser}
		set result [parser get_status]
		# destroy object
		parser destroy
	} else {
		# JSON
		set result [::opsparsers::json2array [_checkmd5 $html]]
		# correct array must be contain even elements
		if [expr {([llength $result] % 2) != 0}] {
			# bad array
			return -code error "array verification failed"
		}
	}
	return $result
}
# ::mondiablo::parseftstatus -- parse diablo node status web page
#
# Parse html or JSON with node status (node_status or ft_status page) from
# diablo web plugin and return formated result.
#
# Arguments:
# html  - string with html page or JSON
#
# Side Effects:
# None.
#
# Results:
# list with arrays as list which contains status of cluster nodes.
# Format of returned structure is:
# { hostname1 {name1 value1 name2 value2 ..}
#   hostname2 {name1 value1 name2 value2 ..}
#   ....
# }
# Error when: 
#  converted from JSON array has incorrect format ("array verification failed")
#  MD5 verification was unsuccessful ("MD5 verification failed")
#  JSON to array conversion was unsuccessful
proc ::mondiablo::parseftstatus {html} {
	# create prns class with variables
	opsprns::obj parser -status 0 -status_table 0 -status_row_list {} -multiline_item 0 -status_item 0 -status_list {}
	# diablo FT status page parser (parser class method)
	parser instproc status_parser {tag state props body} {
		# get access to class variables
		instvar status
		instvar status_table
		instvar status_row_list
		instvar multiline_item
		instvar status_item
		instvar status_list
		# state is empty when tag is open tag
		if {$state == ""} {
			# find <h1>Node status</h1><table> <tr><th>key1</th><th>key2</th>...</tr><tr><td>value1</td><td>value2</td>...</tr>
			if {($tag == "h1") && ($body == "Node status")} {
				set status 1
				set status_table 0
				return
			}
			if {$status && ($tag == "table")} {
				set status_table 1
				set status_table_part ""
				return
			}
			if {$status && $status_table && ($tag == "tr")} {
				set status_row_list {}
				set status_item 1
				return
			}
			if {$status && $status_item && (($tag == "th") || ($tag == "td"))} {
				if {$body != ""} {
					lappend status_row_list [string trim $body " 
"]
					set multiline_item 0
				} else {
					set multiline_item 1
				}
			} elseif {$status && $status_item && $multiline_item && ($tag == "a")} {
				set multiline_item 0
				lappend status_row_list [string trim $body " 
"]
			}
		} else {
			# close tag
			if {$status} {
				if {$tag == "table"} {
					set status 0
				}
				if {($tag == "tr") && ($status_row_list != {})} {
					lappend status_list $status_row_list
					set status_item 0
				}
			}
		}
	}
	parser instproc get_status {} {
		# get access to class variables
		instvar status_list
		array unset result
		# first item in status_list is a header
		set array_key_idx [lsearch -exact [lindex $status_list 0] "link"]
		if {$array_key_idx != -1} {
			# link is present in headers
			foreach row [lrange $status_list 1 end] {
				# get array key
				set hostname [lindex $row $array_key_idx]
				# fill array
				for {set i 0} {$i < [llength $row]} {incr i} {
					# unmap html sequences and add header value pair
					lappend result($hostname) [::opsparsers::unmap_html [lindex [lindex $status_list 0] $i]] [::opsparsers::unmap_html [lindex $row $i]]
				}
			}
		}
		return [array get result]
	}
	# check input data type
	if [regexp -expanded -nocase {.*<html>.*<head>.*</head>.*<body>.*</body>.*</html>.*} $html] {
		# html page with counters
		::opsparsers::HMparse_html $html {parser status_parser}
		array set result [parser get_status]
		# destroy object
		parser destroy
	
	} else {
		# JSON
		set JSONarray_list [::opsparsers::json2array [_checkmd5 $html]]
		# correct array must be contain even elements
		if [expr {([llength $JSONarray_list] % 2) != 0}] {
			# bad array
			return -code error "array verification failed"
		}
		array set result $JSONarray_list
		# check array - all nodes can have "link"
		foreach node [array names result] {
			if {[lsearch -exact $result($node) "link"] == -1} {
				# add link
				lappend result($node) "link" $node
			}
		}
	}
	# convert start_time to unixtime
	foreach node [array names result] {
		array unset node_array
		array set node_array $result($node)
		if {[array names node_array -exact "start_time"] != {}} {
			set node_array(start_time) [clock scan $node_array(start_time)]
		}
		set result($node) [array get node_array]
	}
	return [array get result]
}
# Local Variables:
# mode: tcl
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
