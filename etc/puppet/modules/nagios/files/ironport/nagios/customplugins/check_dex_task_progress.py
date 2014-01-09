#!/usr/bin/python26
"""Nagios monitor for monitoring DEX.  This script will:

1. Check to make sure that <cluster_name>_monitors and
   <cluster_name>_monitor_num_tasks tables exist, WARNING if not.
2. Check to make sure the given monitor ran successfully (and recently
   enough), exiting with a WARNING or CRITICAL if not.
3. If the monitor has run successfully, make sure the data provided by
   the monitor is in the OK state, otherwise, exit with WARNING or
   CRITICAL, depending on the options.

:Status: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_dex_task_progress.py#1 $
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


def check_worker_task_progress(cursor, opt, worker):
    query = """\
SELECT   checked_at, num_tasks
FROM     %s_monitor_num_tasks
WHERE    checked_at > %%s
AND      worker = %%s
ORDER BY checked_at DESC""" % (opt.cluster_name,)
    max_age = int(time.time() - max(opt.warning, opt.critical))
    cursor.execute(query, (max_age, worker,))
    rows = cursor.fetchall()
    if len(rows):
        if len(rows) == 1:
            return 1, "WARN - worker %s may be hung up." % (worker,)
        else:
            # len(rows) > 1
            top_row = rows[0]
            for i in range(1, len(rows)):
                time_delta = top_row[0] - rows[i][0]
                tasks_delta = top_row[1] - rows[i][1]

                if tasks_delta <= 0:
                    if time_delta > opt.critical:
                        return 2, "CRITICAL - worker %s is hung up." % (
                            worker,)
                    elif time_delta > opt.warning:
                        return 1, "WARN - worker %s may be hung up." % (
                            worker,)

            return 0, "OK - woker %s is processing tasks." % (
                worker,)
    else:
        return 2, "CRITICAL - worker %s is not processing tasks." % (
            worker,)


def check_task_progress(cursor, opt):
    query = """\
SELECT DISTINCT(worker)
FROM   %s_monitor_num_tasks""" % (opt.cluster_name,)
    cursor.execute(query)
    rows = cursor.fetchall()
    for row in rows:
        retcode, message = check_worker_task_progress(cursor, opt, row[0])
        if retcode:
            return retcode, message

    return 0, "OK - all workers seem to be processing new tasks."


def check_pending_tasks(cursor, opt):
    # Make sure monitors table exists.
    retcode, messages = check_for_monitor_tables(cursor, opt)
    if retcode:
        return retcode, messages
    
    # Check monitor information.
    mon_name = 'num_pending_tasks'
    query = """\
SELECT success, value
FROM   %s_monitors
WHERE  monitor_name = %%s""" % (opt.cluster_name,)
    cursor.execute(query, (mon_name,))
    rows = cursor.fetchall()
    if len(rows):
        success = bool(int(rows[0][0]))
        value = float(rows[0][1])
        if success:
            if value > 0:
                # There are pending tasks.  Make sure that none of the
                # workers are getting hung up.
                return check_task_progress(cursor, opt)
            else:
                return 0, "OK - no pending tasks."
        else:
            return 2, "CRITICAL - monitor %s failed to run." % (mon_name,)
    else:
        return 1, "WARN - no information found for monitor %s." % (mon_name,)


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
    optParser.add_option('-c', '--critical', dest='critical',
                         action='store', type="int",
                         help="Number of seconds that can elapse without "
                         "additional tasks being processed before reaching "
                         "the CRITICAL state.")
    optParser.add_option('-w', '--warning', dest='warning',
                         action='store', type="int",
                         help="Number of seconds that can elapse without "
                         "additional tasks being processed before reaching "
                         "the WARNING state.")

    try:
        (opt, args) = optParser.parse_args()
    except optparse.OptParseError, err:
        print err
        sys.exit(2)

    if not (opt.host and opt.user and opt.password and
            opt.db and opt.cluster_name and
            opt.critical and opt.warning):
        optParser.print_help()
        sys.exit(2)

    try:
        conn = MySQLdb.connect(user=opt.user, passwd=opt.password, db=opt.db,
                               host=opt.host)
        try:
            cursor = conn.cursor()
            try:
                retcode, messages = check_pending_tasks(cursor, opt)
                print messages
                sys.exit(retcode)
            finally:
                cursor.close()
        finally:
            conn.close()
    except MySQLdb.Error:
        traceback.print_exc(file=sys.stdout)
        sys.exit(2)
