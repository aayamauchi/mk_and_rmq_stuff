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


io()
{
usage=`${stat} counter.disk.usage value` # read + write
if [[ "$usage" == *Error* ]]
then
    echo NaN
else
    echo $usage
fi
}

cpu()
{
cpu=`${stat} counter.cpu.usage value` # percent.
count=`${stat} num_cpu` # count
if [[ "$cpu $count" == *Error* ]]
then
    echo usage:NaN
else
    cpu=`echo "scale=2; $cpu / $count.0" | bc` 
    echo $cpu
fi
}

mem() 
{
usage=`${stat} counter.mem.usage value`
if [[ "$usage" == *Error* ]]
then
    echo NaN
else
    echo $usage
fi
}

net_read() # parse the output [convert to bit/s]
{
read=`${stat} counter.net.received value`
if [[ "$read" == *Error* ]]
then
    echo NaN
else
    read=$(echo "scale=10; $read * 8000" | bc )
    echo $read
fi
}

net_write() # parse the output [convert to bit/s]
{
write=`${stat} counter.net.transmitted value`
if [[ "$write" == *Error* ]]
then
    echo NaN NaN
else
    write=$(echo "scale=10; $write * 8000" | bc )
    echo $write
fi
}

#check_io_vs() # parse the io_vs output from check_esx and present it to statistics
#{
#io_vs_read_latency=`echo $io_vs_all | cut -d" " -f 12 | cut -d= -f 2`
#io_vs_write_latency=`echo $io_vs_all | cut -d" " -f 15 | cut -d= -f 2`
#io_vs_kernel_latency=`echo $io_vs_all | cut -d" " -f 18 | cut -d= -f 2`
#io_vs_device_latency=`echo $io_vs_all | cut -d" " -f 21 | cut -d= -f 2`
#io_vs_queue_latency=`echo $io_vs_all | cut -d" " -f 24 | cut -d= -f 2`
#echo read_latency:$io_vs_read_latency write_latency:$io_vs_write_latency kernel_latency:$io_vs_kernel_latency device_latency:$io_vs_device_latency queue_latency:$io_vs_device_latency
#}

vmfs() 
{
usage=`${stat} datastores $VMFS usage`
if [[ "$usage" == *Error* ]]
then
    echo NaN
else
    echo $usage
fi
}

vm_index() # return a list of vms
{
list=`${stat} vms`
list=`echo $list | tr \[ \ | tr \] \ | tr , \ | tr \' \ `
for item in $list
do
    echo -n "$item "
done
}

vm_query() # return a key:value list of vms
{
list=`${stat} vms`
list=`echo $list | tr \[ \ | tr \] \ | tr , \ | tr \' \ `
for item in $list
do
    echo "${item}:${item}"
done
}

vmfs_index() # return a list of vmfs
{
list=`${stat} ds_list`
list=`echo $list | tr \[ \ | tr \] \ | tr , \ | tr \' \ `
for item in $list
do
    if [ "$item" != "(1)" ]
    then
        echo -n "${item} "
    fi
done
}

vmfs_query() # return a key:value list of vmfs
{
list=`${stat} ds_list`
list=`echo $list | tr \[ \ | tr \] \ | tr , \ | tr \' \ `
for item in $list
do
    if [ "$item" != "(1)" ]
    then
        echo ${item}:${item}
    fi
done
}

# check how we were started and execute accordingly
PATH=/bin:/usr/bin:/usr/local/bin:/usr/share/cacti/scripts
stat="get_vm_stat.py $1"

case "$2" in

  vm_query)
       vm_query
       ;;

  vm_index)
       vm_index
       ;;

  io_usage)
       io
       ;;

  cpu_usage)
       cpu
       ;;

  mem_usage)
       mem
       ;;

  net_read)
       net_read
       ;;

  net_write)
       net_write
       ;;

  vmfs_index)
       vmfs_index 
       ;;

  vmfs_query)
       vmfs_query
       ;;

  vmfs_usage)
       vmfs_usage
       ;;
  *)

       echo "Usage: `basename $0` <Host> <Command> [<VMFS Name>]"
       echo "Command can be any of either: io_usage, cpu_usage, mem_usage, net_read, net_write"
       echo "vm_index, vm_query, vmfs_usage, vmfs_index, vmfs_query"
       exit 0
       ;;

esac
exit 0
