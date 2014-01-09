#!/usr/bin/python26
"""
Phalanx Queue Nagios plugin.


$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/phalanx_queue_check_blade.py#1 $

:Author: mskotyn
"""

import traceback
import MySQLdb

from datetime import datetime
from datetime import timedelta

import base_nagios_plugin as nagios_plugins

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    WBNP Importer state, and return it.
    """

    optp = nagios_plugins.make_option_parser()

    optp.add_option('-q', '--queue-name', dest='queue_name', action='store',
            type='string', help='queue name to check status for')

    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Threshold for phalanx queue status from now for warning'

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Threshold for phalanx queue status from now for for a critical error'

    optp.set_defaults(db_name='phalanx_queue',
                      warn_threshold=5400,
                      critical_threshold=10800)
    return optp

def process_args(optp):
    """
    Given an option parser, optp, execute it and check options for consistency.

    :return: opt, args
    """

    (opt, args) = nagios_plugins.process_args(optp)

    if not opt.queue_name:
         raise nagios_plugins.UsageError('queue-name is required')

    return opt, args

def build_result_msg(result, verbosity, critical_threshold, warn_threshold,
                     last_mtime, time_delta):
    """
    Build a result message based on the verbosity level
    """

    suffix = ''
    if result == nagios_plugins.RESULT_CRITICAL:
        threshold = timedelta(seconds=critical_threshold)
        if verbosity > 0:
            suffix += ', critical threshold = %s' % (threshold,)
    elif result == nagios_plugins.RESULT_WARNING:
        threshold = timedelta(seconds=warn_threshold)
        if verbosity > 0:
            suffix += ', warning threshold = %s' % (threshold,)
    
    if verbosity == 2:
        suffix += '\nThe last update time is %s ' % (last_mtime,)

    return 'Queue is updated %s from now%s' % (time_delta, suffix,)

def check_wbnp_importer_status(opt, args):
    
    mtime_sql = """
                SELECT mtime 
                FROM queue_state 
                WHERE queue_name = "%s" 
                    AND pointer_name = "in";
                """ % (opt.queue_name)
    
                
    
    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    try:
        conn = MySQLdb.Connect(host=opt.db_server,
                               user=opt.db_user,
                               passwd=opt.db_passwd,
                               db=opt.db_name)
        
        nagios_plugins.check_db_schema(conn, 'queue_state', ('queue_name', 'pointer_name', 'mtime'))

    except MySQLdb.OperationalError, e:
        msg = str(e)
        return result, msg
    except nagios_plugins.InvalidDBSchema, e:
        msg = str(e)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            cursor.execute(mtime_sql)
            sql_result = cursor.fetchall()

            if not len(sql_result):
                mtime = None
            else:
                mtime = sql_result[0][0]

            if mtime is None:
                result = nagios_plugins.RESULT_CRITICAL
                msg = 'Queue is not registered in the queue database.'
            else:
                now_time = datetime.now()
                delta = now_time-mtime
                if delta > timedelta(seconds=opt.warn_threshold) and delta < timedelta(seconds=opt.critical_threshold):
                    result = nagios_plugins.RESULT_WARNING
                elif delta > timedelta(seconds=opt.critical_threshold):
                    result = nagios_plugins.RESULT_CRITICAL
                else:
                    result = nagios_plugins.RESULT_OK

                msg = build_result_msg(result,
                                       opt.verbosity,
                                       opt.critical_threshold,
                                       opt.warn_threshold,
                                       mtime, delta)

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
        result, msg = check_wbnp_importer_status(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
