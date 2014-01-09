#!/usr/bin/python26
"""
Pruning-Daemon Nagios plugin.

For more information:
http://eng.ironport.com/docs/is/web_reputation/1_2/eng/ER3/nagios-plugins.rst#pruning-daemon-monitor

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/pruning_check.py#1 $

:Author: moorthi
"""

import sys
import traceback
import MySQLdb

import wbrs_nagios_plugins as nagios_plugins

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    feeds queue, and return it.
    """
    optp = nagios_plugins.make_option_parser()

    optp.set_defaults(db_name='pruning_db',
                      warn_threshold=100000,
                      critical_threshold=1000000)

    return optp

def build_result_msg(verbosity, lengths):
    """
    Build a result message based on the verbosity level

    :param lengths: dict keyed on queue type
    """
    return 'Queue lengths: %s' % (str(lengths))

def count_entries(cursor, type):
    sql = """
SELECT count(*) FROM %s_rule_pruning_queue
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
                if count[t] > opt.critical_threshold:
                    results[t] = nagios_plugins.RESULT_CRITICAL
                elif count[t] > opt.warn_threshold:
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
