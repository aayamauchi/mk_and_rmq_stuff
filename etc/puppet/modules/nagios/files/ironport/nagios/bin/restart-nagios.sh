#!/usr/local/bin/bash

# Checks to see if rsynced nagios config is newer than 5 minutes,
# if so, restart nagios.

PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:/usr/local/nagios/bin
export PATH

# Directory where we put Nagios config files
ETC_DIR=/usr/local/nagios/etc/
os=`uname`

lockfile="/usr/local/nagios/var/nagios.lock"
sendnsca="send_nsca"

if [ ! -f ${lockfile} ]
then
    echo No lockfile, exiting
    exit
fi

if [ -f ${ETC_DIR}send_nsca.cfg ]
then
    nsca_cfg="${ETC_DIR}send_nsca.cfg"
else
    nsca_cfg="/usr/local/etc/send_nsca.cfg"
fi

master="mon.ops.ironport.com"

if [ "$os" = "FreeBSD" ]
then
  rcscript="/usr/local/etc/rc.d/nagios"
else
  rcscript="/etc/init.d/nagios"
fi

# Find files in nagios config newer than the lockfile
newfile=`find ${ETC_DIR} -type f -name '*.cfg' -newer ${lockfile}`
newestfile=`find ${ETC_DIR} -type f -name '*.cfg' -mmin -2`
if [[ "${newfile}" != "" && "${newestfile}" == "" ]]; then
  # We have files that were modified since last restart,
  # and nothing newer than two minutes.  Rsync should be done.
  # So someone did a commit; time to restart!
  modified="yes"
fi

if [ "${modified}" = "yes" ]; then
  sleep 2
  ${rcscript} restart
  sleep 2

  ${rcscript} status
  if [ "$?" = "1" ]; then
    # problem!  restarting again.
    ${rcscript} restart
  fi

  status=`${rcscript} status 2>&1`
  if [ "$?" = "1" ]; then
    # problem!  freaking out
    /usr/bin/printf "`hostname`\tip_snmp_process_nagios\t2\tNagios Poller instance down\n${status}\n\xFF" | \
    ${sendnsca} -H ${master} -c ${nsca_cfg}
    sleep 1
    /usr/bin/printf "`hostname`\tip_snmp_process_nagios\t2\tNagios Poller instance down\n${status}\n\xFF" | \
        ${sendnsca} -H ${master} -c ${nsca_cfg}
    sleep 1
    /usr/bin/printf "`hostname`\tip_snmp_process_nagios\t2\tNagios Poller instance down\n${status}\n\xFF" | \
        ${sendnsca} -H ${master} -c ${nsca_cfg}
  fi
fi
