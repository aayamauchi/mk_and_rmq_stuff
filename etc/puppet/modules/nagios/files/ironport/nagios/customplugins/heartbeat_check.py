#!/usr/bin/python26
"""
Daemons heartbeats check Nagios plugin.

For more information:
http://eng.ironport.com/docs/is/proj/cinema/eng/ds/monitoring_changes-ds.rst#dex-cluster-monitoring-changes

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/heartbeat_check.py#1 $

:Author: vscherb
"""

import sys
import time
import socket
import traceback
import MySQLdb
import base_nagios_plugin as nagios_plugins

from optparse import OptionGroup

DEFAULT_WARN_THRESHOLD     = 120 # secs
DEFAULT_CRITICAL_THRESHOLD = 900 # secs

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    feeds getter, and return it.
    """
    optp = nagios_plugins.make_option_parser()
    
    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Warning threshold (in seconds) for daemon\'s time period' \
                    ' after last successsful update till now. ' \
                    'Default: %s' % DEFAULT_WARN_THRESHOLD

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Critical threshold (in seconds) for daemon\'s time period' \
                    ' after last successsful update till now. ' \
                    'Default: %s' % DEFAULT_CRITICAL_THRESHOLD

    optp.add_option(
        "-H", "--host-name", metavar="HOST_NAME", action="store",
        type="string", dest="host_name",
        help="host-name to check daemons heartbeats on. " \
             "Default: current host name %s" % socket.gethostname())

    optp.add_option(
        "-a", "--app_name", metavar="APP_NAME", action="store",
        type="string", dest="app_name",
        help="app-name to check daemons heartbeats for")
    
    optp.add_option(
        "-C", "--cluster-name", metavar="CLUSTER_NAME", action="store",
        type="string", dest="cluster_name",
        help="use CLUSTER_NAME for the cluster name")

    optp.set_defaults(warn_threshold=DEFAULT_WARN_THRESHOLD,
                      critical_threshold=DEFAULT_CRITICAL_THRESHOLD,
                      host_name=socket.gethostname(),
                      cluster=None)

    return optp


def build_result_msg(opt, data):
    """
    Build a result message based on the verbosity level
    """

    # Sort data to rise the most essential msgs to the top of the msg-list
    sorted_data = list(data.iteritems())
    sorted_data.sort(lambda x,y: cmp(y[0],x[0]))

    msgs = []
    for (result, heartbeats) in sorted_data:
        if not heartbeats: continue

        for (app, cluster, master, host, pid, ts, heartbeat_age) in heartbeats:
        
            msg = 'Master heartbeat %s.%s on %s ' % (app, cluster, master)
            
            if result == nagios_plugins.RESULT_CRITICAL:
                msg += 'has been timed out'
            elif result == nagios_plugins.RESULT_WARNING:
                msg += 'is not fresh'
            else:
                msg += 'looks ok'
            
            if opt.verbosity > 0:
                if result != nagios_plugins.RESULT_OK:
                    msg += ': has not updated in %s secs' % heartbeat_age
                else:
                    msg += ': updated %s secs ago' % heartbeat_age

            if opt.verbosity == 2:

                if result == nagios_plugins.RESULT_CRITICAL:
                    msg += ' (critical_threshold = %s secs)' % \
                           (opt.critical_threshold,)
                elif result == nagios_plugins.RESULT_WARNING:
                    msg += ' (warn_threshold = %s secs)' % \
                           (opt.warn_threshold,)
                else:
                    msg += ' (warn_threshold = %s secs)' % \
                           (opt.warn_threshold,)
            else:
                assert(False, "Invalid verbosity")

            msgs.append(msg)

    return '\n'.join(msgs)


def process_heatbeat_data(opt, heartbeats):
    data = { 
        nagios_plugins.RESULT_OK: [], 
        nagios_plugins.RESULT_WARNING: [],
        nagios_plugins.RESULT_CRITICAL: [],
    }
    max_result = nagios_plugins.RESULT_OK
    for (app, cluster, master, host, pid, ts) in heartbeats:
        heartbeat_age = int(time.time() - ts)

        if heartbeat_age > opt.critical_threshold:
            result = nagios_plugins.RESULT_CRITICAL

        elif heartbeat_age > opt.warn_threshold:
            result = nagios_plugins.RESULT_WARNING

        else:
            result = nagios_plugins.RESULT_OK

        if result > max_result: max_result = result
        data[result].append((app, cluster, master, host, \
                                pid, ts, heartbeat_age),)
    return max_result, data

def check_heartbeat_status(opt, args):
    
    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"

    sql = """SELECT app, cluster, master, host, pid, ts 
                    FROM heartbeats 
                    WHERE app = '%s'
                    AND host = '%s'
          """
    
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)

    try:
        try:
            nagios_plugins.check_db_schema(conn, 
                                           'heartbeats', 
                                           ('app', 'cluster', 'master', 
                                            'host', 'pid', 'ts'))
        except nagios_plugins.InvalidDBSchema, e:
            msg = str(e)
            return result, msg

        cursor = conn.cursor()
        try:
            sql = sql % (opt.app_name, opt.host_name)
            if opt.cluster_name:
                sql +=  " AND cluster = '%s'" % opt.cluster_name

            cursor.execute(sql)
    
            heartbeats = cursor.fetchall()
            if not heartbeats:
                msg = 'Cannot find hearbeats for the cluster ' + \
                      '%s.%s' % (opt.app_name, opt.cluster_name or '*')
                return result, msg
        finally:
            cursor.close()

        result, data = process_heatbeat_data(opt, heartbeats)
        msg = build_result_msg(opt, data)
    
    finally:
        conn.close()

    return result, msg


def main():
    optp = make_option_parser()
    try:
        opt, args = nagios_plugins.process_args(optp)
    except nagios_plugins.UsageError, e:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(e))
        
    try:
        result, msg = check_heartbeat_status(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
