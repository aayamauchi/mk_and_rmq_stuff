#!/usr/bin/env python2.6
"""
Feeds Importer's queue monitor.

For more information:
http://eng.ironport.com/docs/is/wbrs_rule_lib/1.0/eng/ds/wbrs_rule_lib-ds.rst

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/feeds_importer_queue_monitor.py#2 $

:Author: moorthi, ydidukh, mskotyn
"""

import traceback
import MySQLdb
import base_nagios_plugin as nagios_plugins

DEFAULT_WARN_THRESHOLD     = 100
DEFAULT_CRITICAL_THRESHOLD = 500

def make_option_parser():
    """Build a NagiosOptionParser.

    Populate it with arguments for checking the feeds queue, and return it.
    """
    optp = nagios_plugins.make_option_parser()

    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Feedfile chunks count for warning. ' + \
                    'Default: %d' % (DEFAULT_WARN_THRESHOLD,)

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Feedfile chunks count for a critical error. ' + \
                    'Default: %d' % (DEFAULT_CRITICAL_THRESHOLD,)

    optp.set_defaults(db_name='webcat_data_set',
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
        raise AssertionError("Invalid verbosity")


def check_feeds_queue_status(opt):
    """Check the queue using queue_state table for 'in' and 'out' pointers."""
    length_sql = """
SELECT i.odometer - o.odometer
FROM queue_state i JOIN queue_state o
WHERE i.pointer_name = 'in' AND o.pointer_name = 'out';
"""

    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)

    try:
        nagios_plugins.check_db_schema(conn,
                                       'queue_state',
                                       ('odometer', 'pointer_name'))
    except nagios_plugins.InvalidDBSchema, err:
        msg = str(err)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            # Get the queue length.
            cursor.execute(length_sql)
            length = cursor.fetchall()[0][0]

            if length > opt.critical_threshold:
                result = nagios_plugins.RESULT_CRITICAL
                msg = build_result_msg(opt.verbosity,
                                       opt.critical_threshold,
                                       length)
            elif length > opt.warn_threshold:
                result = nagios_plugins.RESULT_WARNING
                msg = build_result_msg(opt.verbosity,
                                       opt.warn_threshold,
                                       length)
            else:
                result = nagios_plugins.RESULT_OK
                msg = build_result_msg(0, 0, length)
        finally:
            cursor.close()
    finally:
        conn.close()

    return result, msg

def main():
    """The main method executed by default."""
    optp = make_option_parser()
    try:
        opt, _ = process_args(optp)
    except nagios_plugins.UsageError, err:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(err))

    try:
        result, msg = check_feeds_queue_status(opt)
    except Exception, err:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(err))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
