#!/usr/local/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

OUTPUT=`snmpget -v2c -c $2 -OQvn $1 .1.3.6.1.4.1.8072.1.3.2.3.1.2.\"nagiostats_cacti\"`

# 512 character limit for output.  time to break up into edible chunks.
case $3 in
	1)
		echo $OUTPUT | cut -f 1-24 -d\ 
		;;
	2)
		echo $OUTPUT | cut -f 25-40 -d\ 
		;;
	ACTHST)
		# MIN/MAX/AVG Active Host
		for x in $OUTPUT
		do
			if [ "${x:3:6}" == "ACTHST" ] && [ "${x:0:3}" != "NUM" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	PSVHST)
		# MIN/MAX/AVG Passive Host
		for x in $OUTPUT
		do
			if [ "${x:3:6}" == "PSVHST" ] && [ "${x:0:3}" != "NUM" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	ACTSVC)
		# MIN/MAX/AVG Active Service
		for x in $OUTPUT
		do
			if [ "${x:3:6}" == "ACTSVC" ] && [ "${x:0:3}" != "NUM" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	PSVSVC)
		# MIN/MAX/AVG Passive Service
		for x in $OUTPUT
		do
			if [ "${x:3:6}" == "PSVSVC" ] && [ "${x:0:3}" != "NUM" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	PSC)
		# MIN/MAX/AVG PSC
		for x in $OUTPUT
		do
			if [ "${x:6:3}" == "PSC" ] || [ "${x:9:3}" == "PSC" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	LAT)
		# MIN/MAX/AVG LAT
		for x in $OUTPUT
		do
			if [ "${x:6:3}" == "LAT" ] || [ "${x:9:3}" == "LAT" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	EXT)
		# MIN/MAX/AVG EXT
		for x in $OUTPUT
		do
			if [ "${x:6:3}" == "EXT" ] || [ "${x:9:3}" == "EXT" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	NUMACT)
		# Active checks
		for x in $OUTPUT
		do
			if [ "${x:0:6}" == "NUMACT" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	NUMCACHED)
		# Cached checks
		for x in $OUTPUT
		do
			if [ "${x:0:6}" == "NUMCAC" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	NUMEXT)
		# External Commands
		for x in $OUTPUT
		do
			if [ "${x:0:6}" == "NUMEXT" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	NUMOACT)
		# On-demand checks
		for x in $OUTPUT
		do
			if [ "${x:0:6}" == "NUMOAC" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	NUMPAR)
		# Parallel checks
		for x in $OUTPUT
		do
			if [ "${x:0:6}" == "NUMPAR" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	NUMPSV)
		# Passive
		for x in $OUTPUT
		do
			if [ "${x:0:6}" == "NUMPSV" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	NUMSACT)
		# Scheduled
		for x in $OUTPUT
		do
			if [ "${x:0:6}" == "NUMSAC" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	NUMSER)
		# Serial checks
		for x in $OUTPUT
		do
			if [ "${x:0:7}" == "NUMSERH" ]
			then
				OUT=`printf "%s" "$OUT $x"`
			fi
		done
		echo $OUT
		;;
	*)
		for x in `echo "$OUTPUT NOTE:000000000 CACTICHARACTERLIMIT:512"`
		do
			echo $x
		done
	
esac	
