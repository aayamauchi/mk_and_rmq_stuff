#!/usr/local/bin/bash
#
# Make graphs in statistics based on check_esx3 by op5
# 0.1
# mikael.schmidt@ixx.se
#
# 0.2
# Added: mem, cpu, net for VM & VS
# giancarlo.birello@cnr.it
#
# 0.5
# switched to reading from pickled cache.

PATH=/bin:/usr/bin:/usr/local/bin:/usr/share/cacti/scripts:/usr/local/ironport/nagios/bin


check_io()
{
read=`${stat} counter.disk.read value` # kB/second
write=`${stat} counter.disk.write value` # kB/second
usage=`${stat} counter.disk.usage value` # read + write
if [[ "$read $write $usage" == *Error* ]]
then
    echo usage:NaN read:NaN write:NaN
    exit
fi
echo usage:$usage read:$read write:$write
}

check_cpu()
{
cpu=`${stat} counter.cpu.usage value` # percent.
count=`${stat} num_cpu` # count
if [[ "$cpu $count" == *Error* ]]
then
    echo usage:NaN
    exit
fi
cpu=`echo "scale=2; $cpu / $count.0" | bc` 
echo usage:$cpu
}

check_mem() 
{
usage=`${stat} counter.mem.usage value`
active=`${stat} counter.mem.active value`
if [[ "$usage $active" == *Error* ]]
then
    echo usage:NaN active:NaN
    exit
fi
echo usage:$usage active:$active
}

check_net() # parse the output [convert to bit/s]
{
read=`${stat} counter.net.received value`
write=`${stat} counter.net.transmitted value`
if [[ "$read $write" == *Error* ]]
then
    echo read:NaN write:NaN
    exit
fi
read=$(echo "scale=10; $read * 8000" | bc )
write=$(echo "scale=10; $write * 8000" | bc )
echo read:$read write:$write
}

check_io_vs() # parse the io_vs output from check_esx and present it to statistics
{
io_vs_read_latency=`echo $io_vs_all | cut -d" " -f 12 | cut -d= -f 2`
io_vs_write_latency=`echo $io_vs_all | cut -d" " -f 15 | cut -d= -f 2`
io_vs_kernel_latency=`echo $io_vs_all | cut -d" " -f 18 | cut -d= -f 2`
io_vs_device_latency=`echo $io_vs_all | cut -d" " -f 21 | cut -d= -f 2`
io_vs_queue_latency=`echo $io_vs_all | cut -d" " -f 24 | cut -d= -f 2`
echo read_latency:$io_vs_read_latency write_latency:$io_vs_write_latency kernel_latency:$io_vs_kernel_latency device_latency:$io_vs_device_latency queue_latency:$io_vs_device_latency
}

check_vmfs_vs() # parse the vmfs_vs output [% value] from check_esx3 and present it to statistics
{
capacity=`${stat} datastores $VMFS capacity`
free=`${stat} datastores $VMFS freeSpace`
echo capacity:$capacity free:$free
}

list_vmx() # return a list of vms
{
list=`${stat} vms`
list=`echo $list | tr \[ \ | tr \] \ | tr , \ | tr \' \ `
for item in $list
do
    echo $item
done
}

list_vm() # return a key:value list of vms
{
list=`${stat} vms`
list=`echo $list | tr \[ \ | tr \] \ | tr , \ | tr \' \ `
for item in $list
do
    echo "${item}:${item}"
done
}

list_vmfsx() # return a list of vmfs
{
list=`${stat} ds_list`
list=`echo $list | tr \[ \ | tr \] \ | tr , \ | tr \' \ `
for item in $list
do
    echo ${item}
done
}

list_vmfs() # return a key:value list of vmfs
{
list=`${stat} ds_list`
list=`echo $list | tr \[ \ | tr \] \ | tr , \ | tr \' \ `
for item in $list
do
    echo ${item}:${item}
done
}

# check how we were started and execute accordingly
PATH=/bin:/usr/bin:/usr/local/bin:/usr/share/cacti/scripts
scripts="/usr/share/cacti/scripts"
stat="get_vm_stat.py $3"

if [ "$5" != "" ]
then
    UN=$4
    PW=$5
else
    UN=nagios
    PW=BKidKOEXoW8s
fi

case "$1" in

  io_vm*)
       check_io
       ;;

  cpu_vm*)
       check_cpu
       ;;

  mem_vm*)
       check_mem
       ;;

  net_vm*)
       check_net
       ;;

  list_vmfsx)
       stat="get_vm_stat.py $2"
       list_vmfsx
       ;;

  list_vmfs)
       stat="get_vm_stat.py $2"
       list_vmfs
       ;;

  list_vmx)
       stat="get_vm_stat.py $2"
       list_vmx
       ;;

  list_vm)
       stat="get_vm_stat.py $2"
       list_vm
       ;;

  io_vs)
       stat="get_vm_stat.py $2"
       check_io
       ;;

  cpu_vs)
       stat="get_vm_stat.py $2"
       check_cpu
       ;;

  mem_vs)
       stat="get_vm_stat.py $2"
       check_mem
       ;;

  net_vs)
       stat="get_vm_stat.py $2"
       check_net
       ;;

  vmfs_vs)
       stat="get_vm_stat.py $2"
       VMFS=$3
       check_vmfs_vs
       ;;
  *)

       echo "Usage: `basename $0` <Command> <VS Host> [<VM Name>|<VMFS Name>] [<Username>] [<Password>]"
       echo "Command can be any of either: io_vm, cpu_vm, mem_vm, net_vm, io_vs, cpu_vs, mem_vs, net_vs"
       echo "vmfs_vs list_vm list_vmfs"
       echo "When using a *_vs command you cannot specify a VM Name"
       exit 0
       ;;

esac
exit 0
