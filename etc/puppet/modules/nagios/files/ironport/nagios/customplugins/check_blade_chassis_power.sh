#!/usr/local/bin/bash
ps_base_oid="1.3.6.1.4.1.232.22.2.5.1.1.1"
blade_base_oid="1.3.6.1.4.1.232.22.2.4.1.1.1"
ps_status_oid="$ps_base_oid.14"
ps_condition_oid="$ps_base_oid.17"
ps_serno_oid="$ps_base_oid.5"
ps_cur_pwr_oid="$ps_base_oid.10"
ps_max_pwr_oid="$ps_base_oid.9"
ps_temp_int_oid="$ps_base_oid.12"
ps_temp_ext_oid="$ps_base_oid.13"

blade_name_oid="$blade_base_oid.4"
blade_serno_oid="$blade_base_oid.16"

if [ $# -lt 2 ]
then 
	echo "Too few arguments"
	echo "Usage:check_blade_ps [-s status] [-c condition] [-p current power output] [-i intake air temp] [-x exit/exhaust air temp] <blade-chassis-hostname>"
    	exit 3
else

chassisname=${!#}

#Check to see if they've asked for a valid chassis hostname
#Normally, we'd do this through Awesome, but since that doesn't let you query rolemaps or profiles, we're kind of stuck with host/dig. 
#When I say "stuck" it means I'm merely wishing for a tool that had consistent exit codes between OS flavors
result=`host $chassisname`
if echo $result|grep -q "not found"
then
	echo "Invalid hostname:$chassisname...exiting"
	exit 3
fi

while getopts "cipx" Option
do
case $Option in

	     c) probe_oid=$ps_condition_oid;
		bladenum=1;
		badps=0;
		goodps=0;
		result=`snmpwalk -c 'y3ll0w!' -v 2c $chassisname $probe_oid|cut -d " " -f 4`;
		for psstat in $result
		do
		  if [ "$psstat" -eq 2 ]; 
		  then
		 	   state=0;
			   ((goodps +=1));
		  else
		    blade_name=`snmpget -c 'y3ll0w!' -v 2c $chassisname $blade_name_oid.$bladenum 2>/tmp/pserr|cut -d " " -f 4`;
		    bad_pslist=`echo $bad_pslist $blade_name`;
		    (( badps +=1 ))
			   state=2;
		  fi
		    (( bladenum +=1 ))
		done
			if [ "$badps" -gt 0 ];
			then
			    state=2;
			else
			    state=0;
			fi
		        bad_ps_str="$badps faults:$bad_pslist";
			good_ps_str="$goodps OK"
			resultstr="Power supply status: $good_ps_str $bad_ps_str"
		break;
		;;
	     i) probe_oid=$ps_temp_int_oid;
		result=`snmpget -c 'y3ll0w!' -v 2c $chassisname $probe_oid.$bladenum`;
		break;
		;;
	     p) probe_oid=$ps_cur_pwr_oid;
		result=`snmpget -c 'y3ll0w!' -v 2c $chassisname $probe_oid.$bladenum|cut -d " " -f 4`;
		if [ "$result" -lt 600 ] ; 
		then 
		    psn=`snmpget -c 'y3ll0w!' -v 2c $chassisname $ps_serno_oid.$bladenum|cut -d " " -f 4`;
		    resultstr="$chassisname:UNDERVOLT on PS $psn: $result < 600";
		    state=2;
		else
		    resultstr="$chassisname:Power Supply voltage $result volts OK";
		    state=0;
		fi
		break;
		;;
	     x) probe_oid=$ps_temp_ext_oid;
		result=`snmpget -c 'y3ll0w!' -v 2c $chassisname $probe_oid.$bladenum`;
		break;
		;;
esac
done
fi
echo $resultstr
exit $state
