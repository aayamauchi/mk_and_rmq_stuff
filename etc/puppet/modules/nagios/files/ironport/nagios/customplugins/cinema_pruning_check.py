#!/usr/bin/python26
"""
Pruning-Daemon Nagios plugin.

For more information:
http://eng.ironport.com/docs/is/web_reputation/1_2/eng/ER3/nagios-plugins.rst#pruning-daemon-monitor

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/cinema_pruning_check.py#1 $

:Author: moorthi
"""

import sys
import traceback
import MySQLdb
import base_nagios_plugin as nagios_plugins

DEFAULT_WARN_THRESHOLD     = 1000
DEFAULT_CRITICAL_THRESHOLD = 10000

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    feeds queue, and return it.
    """
    optp = nagios_plugins.make_option_parser()

    opt_warn = optp.get_option('-w')
    opt_warn.help='Rule prunning queue lengths for warning. ' + \
                  'Default: %d' % DEFAULT_WARN_THRESHOLD

    opt_crit = optp.get_option('-c')
    opt_crit.help='Rule prunning queue lengths for a critical error. ' + \
                  'Default: %d' % DEFAULT_CRITICAL_THRESHOLD

    optp.add_option('--ip-warn-threshold', dest='ip_warn_threshold',
            action='store', type='int',
            help='IP-rule prunning queue lengths for warning')
    optp.add_option('--ip-critical-threshold', dest='ip_critical_threshold',
            action='store', type='int',
            help='IP-rule prunning queue lengths for a critical error')
    optp.add_option('--prefix-warn-threshold', dest='prefix_warn_threshold',
            action='store', type='int',
            help='Prefix-rule prunning queue lengths for warning')
    optp.add_option('--prefix-critical-threshold', dest='prefix_critical_threshold',
            action='store', type='int',
            help='Prefix-rule prunning queue lengths for a critical error')
            
    optp.set_defaults(db_name='pruning_db',
                      ip_warn_threshold=0,
                      ip_critical_threshold=0,
                      prefix_warn_threshold=0,
                      prefix_critical_threshold=0,
                      warn_threshold=DEFAULT_WARN_THRESHOLD,
                      critical_threshold=DEFAULT_CRITICAL_THRESHOLD)

    return optp

def build_result_msg(verbosity, lengths):
    """
    Build a result message based on the verbosity level

    :param lengths: dict keyed on queue type
    """
    return 'Queue lengths: %s' % (str(lengths))

def count_entries(cursor, type):
    sql = """
SELECT count(*)
FROM %s_rule_pruning_queue
WHERE request_cnt <> 0
""" % (type,)
    cursor.execute(sql)
    return cursor.fetchall()[0][0]

def check_pruning_status(opt, args):
    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)

    queue_types = ('ip', 'prefix')
    try:
        for t in queue_types:
            nagios_plugins.check_db_schema(conn, '%s_rule_pruning_queue' % (t,), ())
    except nagios_plugins.InvalidDBSchema, e:
        msg = str(e)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            count = {}
            results = {}
            for t in queue_types:
                count[t] = count_entries(cursor, t)
                    
                warn_threshold     = getattr(opt, t + '_warn_threshold') or\
                                     opt.warn_threshold
                critical_threshold = getattr(opt, t + '_critical_threshold') or\
                                     opt.critical_threshold

                if count[t] > critical_threshold:
                    results[t] = nagios_plugins.RESULT_CRITICAL
                elif count[t] > warn_threshold:
                    results[t] = nagios_plugins.RESULT_WARNING
                else:
                    results[t] = nagios_plugins.RESULT_OK

            if nagios_plugins.RESULT_CRITICAL in results.values():
                result = nagios_plugins.RESULT_CRITICAL
            elif nagios_plugins.RESULT_WARNING in results.values():
                result = nagios_plugins.RESULT_WARNING
            else:
                result = nagios_plugins.RESULT_OK

            msg = build_result_msg(opt.verbosity, count)
        finally:
            cursor.close()
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
        result, msg = check_pruning_status(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
