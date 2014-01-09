#!/usr/bin/python26
"""
Feeds-queue Nagios plugin.

For more information:
http://eng.ironport.com/docs/is/web_reputation/1_2/eng/ER3/nagios-plugins.rst#feeds-queue-monitor

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/feeds_queue_check_blade.py#1 $

:Author: moorthi
"""

import sys
import traceback
import MySQLdb
import base_nagios_plugin as nagios_plugins

DEFAULT_WARN_THRESHOLD     = 100
DEFAULT_CRITICAL_THRESHOLD = 500

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    feeds queue, and return it.
    """
    optp = nagios_plugins.make_option_parser()

    opt_warn = optp.get_option('-w')
    opt_warn.help='Feedfile chunks count for warning. ' + \
                  'Default: %d' % DEFAULT_WARN_THRESHOLD

    opt_crit = optp.get_option('-c')
    opt_crit.help='Feedfile chunks count for a critical error. ' + \
                  'Default: %d' % DEFAULT_CRITICAL_THRESHOLD

    optp.set_defaults(db_name='raw_data_set',
                      warn_threshold=DEFAULT_WARN_THRESHOLD,
                      critical_threshold=DEFAULT_CRITICAL_THRESHOLD)

    return optp

def process_args(optp):
    """
    Given an option parser, optp, execute it and check options for consistency.

    :return: opt, args
    """
    (opt, args) = nagios_plugins.process_args(optp)

    return opt, args

def build_result_msg(verbosity, threshold, length):
    """
    Build a result message based on the verbosity level
    """
    if verbosity < 2:
        return 'Queue length is %d' % (length,)
    elif verbosity == 2:
        return 'Threshold = %d, Queue length is %d' % (threshold, length)
    else:
        assert(False, "Invalid verbosity")


def check_feeds_queue_status(opt, args):
    length_sql = """
SELECT i.odometer - o.odometer
FROM queue_state i JOIN queue_state o
WHERE i.pos_type = 'in' AND o.pos_type = 'out';
"""

    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)

    try:
        nagios_plugins.check_db_schema(conn, 'queue_state', ('odometer', 'pos_type'))
        nagios_plugins.check_db_schema(conn, 'source_rules', ())
    except nagios_plugins.InvalidDBSchema, e:
        msg = str(e)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            # Get the queue length
            cursor.execute(length_sql)
            length = cursor.fetchall()[0][0]
            
            if length > opt.critical_threshold:
                result = nagios_plugins.RESULT_CRITICAL
                msg = build_result_msg(opt.verbosity, opt.critical_threshold, length)
            elif length > opt.warn_threshold:
                result = nagios_plugins.RESULT_WARNING
                msg = build_result_msg(opt.verbosity, opt.warn_threshold, length)
            else:
                result = nagios_plugins.RESULT_OK
                msg = build_result_msg(0, 0, length)
        finally:
            cursor.close()
    finally:
        conn.close()

    return result, msg

def main():
    optp = make_option_parser()
    try:
        opt, args = process_args(optp)
    except nagios_plugins.UsageError, e:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(e))
        
    try:
        result, msg = check_feeds_queue_status(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
