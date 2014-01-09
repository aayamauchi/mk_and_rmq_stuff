#!/usr/bin/python26
"""
WBNP Loader Nagios plugin.

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/wbnp_loader_check_blade.py#1 $

:Author: nfriess
"""

import sys
import traceback
import socket
import MySQLdb
import time

from datetime import timedelta

import base_nagios_plugin as nagios_plugins

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    WBNP Loader state, and return it.
    """

    optp = nagios_plugins.make_option_parser()


    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Threshold for wbnp_loader status from now for warning'

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Threshold for wbnp_loader status from now for for a critical error'

    optp.set_defaults(app_server=socket.gethostname(),
                      db_name='wbnp',
                      warn_threshold=172800,
                      critical_threshold=432000)

    return optp

def process_args(optp):
    """
    Given an option parser, optp, execute it and check options for consistency.

    :return: opt, args
    """
    (opt, args) = nagios_plugins.process_args(optp)

    return opt, args

def build_result_msg(result, verbosity, critical_threshold, warn_threshold,
                     last_store_ts):
    """
    Build a result message based on the verbosity level
    """
    
    now_time = int(time.mktime(time.localtime()))
    time_delta = None
    if last_store_ts: 
        time_delta = timedelta(seconds=(now_time-last_store_ts))

    if result == nagios_plugins.RESULT_OK:
        if time_delta:
            return "Loader is %s behind" % time_delta
        else:
            return "No stores to laod"
    else:
        if result == nagios_plugins.RESULT_CRITICAL:
            threshold = timedelta(seconds=critical_threshold)
        else:
            threshold = timedelta(seconds=warn_threshold)
                
        if last_store_ts is None:
            return 'Loader is below the set threshold = %s from now' % (threshold,)

        last_store_ts_utc = time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime(last_store_ts))
            
        suffix = ''
        if verbosity > 0:
            suffix += ' that is below the set threshold = %s' % (threshold,)
        if verbosity == 2:
            suffix += '\nThe last processed WBNP store is %s (%s)' % (last_store_ts, last_store_ts_utc,)

        return 'Loader is %s from now%s' % (time_delta, suffix,)
            
def check_wbnp_loader_status(opt, args):
    
    check_store_sql = """
                SELECT COUNT(*)
                FROM wbnp_store_status
                WHERE state='loaded_to_wumpus' AND
                      interval_end > (UNIX_TIMESTAMP(UTC_TIMESTAMP()) - %d);
                """

    last_storets_sql = """
                SELECT MAX(interval_end)
                FROM wbnp_store_status
                WHERE state='loaded_to_wumpus';
                """

    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    try:
        conn = MySQLdb.Connect(host=opt.db_server,
                               user=opt.db_user,
                               passwd=opt.db_passwd,
                               db=opt.db_name)
        
        nagios_plugins.check_db_schema(conn, 'wbnp_store_status', ('interval_end','state'))

    except MySQLdb.OperationalError, e:
        msg = str(e)
        return result, msg
    except nagios_plugins.InvalidDBSchema, e:
        msg = str(e)
        return result, msg

    try:
        cursor = conn.cursor()
        try:

            cursor.execute(check_store_sql % opt.critical_threshold)
            count = cursor.fetchall()[0][0]

            if count == 0:
                result = nagios_plugins.RESULT_CRITICAL
            else:
                cursor.execute(check_store_sql % opt.warn_threshold)
                count = cursor.fetchall()[0][0]

                if count == 0:
                    result = nagios_plugins.RESULT_WARNING
                else:
                    result = nagios_plugins.RESULT_OK

            cursor.execute(last_storets_sql)
            sql_result = cursor.fetchall()

            if not len(sql_result):
                last_store_ts = None
            else:
                last_store_ts = sql_result[0][0]               

            msg = build_result_msg(result,
                                   opt.verbosity,
                                   opt.critical_threshold,
                                   opt.warn_threshold,
                                   last_store_ts)

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
        result, msg = check_wbnp_loader_status(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
