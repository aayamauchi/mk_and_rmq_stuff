#!/usr/bin/python26
"""Nagios monitor for monitoring DEX.  This script will:

1. Check to make sure that <cluster_name>_monitors and
   <cluster_name>_monitor_num_tasks tables exist, WARNING if not.
2. Check to make sure the given monitor ran successfully (and recently
   enough), exiting with a WARNING or CRITICAL if not.
3. If the monitor has run successfully, make sure the data provided by
   the monitor is in the OK state, otherwise, exit with WARNING or
   CRITICAL, depending on the options.

:Status: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_dex_monitors.py#1 $
:Authors: jwescott
"""

import optparse
import MySQLdb
import MySQLdb.cursors
import sys
import time
import traceback


SECS = 0
MINVAL = 1
MAXVAL = 2


def check_for_monitor_tables(cursor, opt):
    query = """\
SHOW TABLES
FROM %s
LIKE '%s_monitors'""" % (opt.db, opt.cluster_name,)
    cursor.execute(query)
    monitors = cursor.fetchall()

    query = """\
SHOW TABLES
FROM %s
LIKE '%s_monitor_num_tasks'""" % (opt.db, opt.cluster_name,)
    cursor.execute(query)
    monitor_nt = cursor.fetchall()

    if len(monitors) < 1:
        return 1, "WARN - table %s_monitors does not exist in %s." % (
            opt.cluster_name, opt.db,)
    elif len(monitor_nt) < 1:
        return 1, "WARN - table %s_monitor_num_tasks does not exist in %s." % (
            opt.cluster_name, opt.db,)
    else:
        return (
            0,
            "OK - tables %s_monitors and %s_monitor_num_tasks exist "
            "in %s." % (opt.cluster_name, opt.cluster_name, opt.db,), )


def check_monitor_timestamp(cursor, opt):
    query = """\
SELECT last_ran, success
FROM   %s_monitors
WHERE  monitor_name = %%s""" % (opt.cluster_name,)
    cursor.execute(query, (opt.monitor,))
    rows = cursor.fetchall()
    if len(rows):
        now = time.time()
        last_ran = int(rows[0][0])
        success = int(rows[0][1])
        age = now - last_ran
        if not success:
            return 2, "CRITICAL - %s monitor failed when it ran." % (
                opt.monitor,)
        elif age > opt.critical.secs:
            return 2, "CRITICAL - %s monitor hasn't run in %d seconds." % (
                opt.monitor, age,)
        elif age > opt.warning.secs:
            return 1, "WARN - %s monitor hasn't run in %d seconds." % (
                opt.monitor, age,)
        else:
            return 0, "OK - %s monitor ran %d seconds ago." % (
                opt.monitor, age,)
    else:
        return 1, "WARN - no information found for monitor %s." % (
            opt.monitor,)


def check_monitor_value(opt, value):
    # heartbeat: ms_ago
    # num_pending_tasks: num
    # num_running_workers: num
    # ping_monitoring_ui: rt_ms
    # ping_primary_scheduler: rt_ms
    # top_job_progress: ms_ago
    retcode = 0, "OK - %s monitor value (%.2f) is within range." % (
        opt.monitor, value,)
    if value < opt.critical.min_val:
        retcode = 2, "CRITICAL - %s monitor value (%.2f) is too low." % (
            opt.monitor, value,)
    elif value > opt.critical.max_val:
        retcode = 2, "CRITICAL - %s monitor value (%.2f) is too high." % (
            opt.monitor, value,)
    elif value < opt.warning.min_val:
        retcode = 1, "WARN - %s monitor value (%.2f) is almost too low." % (
            opt.monitor, value,)
    elif value > opt.warning.max_val:
        retcode = 1, "WARN - %s monitor value (%.2f) is almost too high." % (
            opt.monitor, value,)

    return retcode

def check_monitor(cursor, opt):
    # Make sure monitors table exists.
    retcode, messages = check_for_monitor_tables(cursor, opt)
    if retcode:
        return retcode, messages
    
    # Make sure monitor ran recently.
    retcode, messages = check_monitor_timestamp(cursor, opt)
    if retcode:
        return retcode, messages
    
    # Check monitor information.
    query = """\
SELECT value
FROM   %s_monitors
WHERE  monitor_name = %%s""" % (opt.cluster_name,)
    cursor.execute(query, (opt.monitor,))
    rows = cursor.fetchall()
    if len(rows):
        return check_monitor_value(opt, float(rows[0][0]))
    else:
        return 1, "WARN - no information found for monitor %s." % (
            opt.monitor,)


if __name__ == '__main__':
    optParser = optparse.OptionParser()

    optParser.add_option("-H", "--host", dest="host",
                         help="Host to monitor.")
    optParser.add_option("-u", "--user", dest="user",
                         help="User to connect with.")
    optParser.add_option("-p", "--password", dest="password",
                         help="Password to connect with.")
    optParser.add_option("-d", "--db", dest="db",
                         help="Database to monitor.")
    optParser.add_option("-C", "--cluster-name", dest="cluster_name",
                         help="Cluster name to monitor.")
    optParser.add_option("-m", "--monitor", dest="monitor",
                         help="Which monitor to check.")
    optParser.add_option('-c', '--critical', dest='critical',
                         action='store', type="string",
                         help="CRITICAL state argument of the form: "
                         "<secs>,<min_val>,<max_val> where <secs> is the "
                         "maximum number of seconds that can elapse "
                         "without the monitor running successfully, "
                         "<min_val> is the minimum value of the monitor, "
                         "and <max_val> is the maximum value of the monitor.")
    optParser.add_option('-w', '--warning', dest='warning',
                         action='store', type="string",
                         help="WARNING state argument of hte form: "
                         "<secs>,<min_val>,<max_val> where <secs> is the "
                         "maximum number of seconds that can elapse "
                         "without the monitor running successfully, "
                         "<min_val> is the minimum value of the monitor, "
                         "and <max_val> is the maximum value of the monitor.")

    try:
        (opt, args) = optParser.parse_args()
    except optparse.OptParseError, err:
        print err
        sys.exit(2)

    if not (opt.host and opt.user and opt.password and
            opt.db and opt.cluster_name and opt.monitor and
            opt.critical and opt.warning):
        optParser.print_help()
        sys.exit(2)
    else:
        # parse the critical and warning options
        class struct(object): pass
        critical = [ float(x) for x in opt.critical.split(",") ][0:4]
        assert(len(critical) == 3)
        opt.critical = struct()
        opt.critical.secs = critical[0]
        opt.critical.min_val = critical[1]
        opt.critical.max_val = critical[2]
        warning = [ float(x) for x in opt.warning.split(",") ][0:4]
        assert(len(warning) == 3)
        opt.warning = struct()
        opt.warning.secs = warning[0]
        opt.warning.min_val = warning[1]
        opt.warning.max_val = warning[2]

    try:
        conn = MySQLdb.connect(user=opt.user, passwd=opt.password, db=opt.db,
                               host=opt.host)
        try:
            cursor = conn.cursor()
            try:
                retcode, messages = check_monitor(cursor, opt)
                print messages
                sys.exit(retcode)
            finally:
                cursor.close()
        finally:
            conn.close()
    except MySQLdb.Error:
        traceback.print_exc(file=sys.stdout)
        sys.exit(2)
