#!/usr/bin/python26
"""
WBNP Importer Nagios plugin.

For more information:
http://eng.ironport.com/docs/is/web_reputation/1_2/eng/ER3/nagios-plugins.rst#wbnp-importer-monitor

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/wbnp_importer_check.py#1 $

:Author: vscherb
"""

import sys
import traceback
import socket
import MySQLdb
import time

from datetime import timedelta

import wbrs_nagios_plugins as nagios_plugins


def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    WBNP Importer state, and return it.
    """

    optp = nagios_plugins.make_option_parser()

    optp.add_option('-a', '--app-server', dest='app_server', action='store',
            type='string', help='app-server to check status for')

    optp.add_option('-n', '--app-name', dest='app_name', action='store',
            type='string', help='app name of the URL importer to check status for')

    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Threshold for wbnp_importer status from now for warning'

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Threshold for wbnp_importer status from now for for a critical error'

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

    if not opt.app_server:
        raise nagios_plugins.UsageError('app-server is required')

    if not opt.app_name:
        raise nagios_plugins.UsageError('app-name is required')

    return opt, args

def build_result_msg(result, verbosity, critical_threshold, warn_threshold,
                     state, last_logts):
    """
    Build a result message based on the verbosity level
    """
    
    if state is None:
        return "Importer is not registered in wbnp.data_apps"
    elif state != 'active':
        return "Importer is not active"
    else:          
        if result == nagios_plugins.RESULT_CRITICAL:
            threshold = timedelta(seconds=critical_threshold)
        else:
            threshold = timedelta(seconds=warn_threshold)
            
        if last_logts is None and result != nagios_plugins.RESULT_OK:
            return 'Importer is behind by at least %s' % (threshold,)

        last_logts_utc = time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime(last_logts))
        now_time = int(time.mktime(time.gmtime()))
        time_delta = timedelta(seconds=(now_time-last_logts))
        
        suffix = ''
        if verbosity > 0:
            suffix += ' (past threshold = %s)' % (threshold,)
        if verbosity == 2:
            suffix += '\nThe last processed log timestamp is %s (%s)' % (last_logts, last_logts_utc,)

        return 'Importer is %s from now in the logs%s' % (time_delta, suffix,)
            
def check_wbnp_importer_status(opt, args):
    
    state_sql = """
                SELECT state
                FROM data_apps
                WHERE app_name = '%s'
                  AND host_name = '%s';
                """ % (opt.app_name, opt.app_server)

    count_sql = """
                SELECT COUNT(*)
                FROM importer_ledger il, data_apps da
                WHERE il.logts > (UNIX_TIMESTAMP(now()) - %%d)
                  AND il.data_app_id = da.data_app_id
                  AND da.app_name = '%s'
                  AND host_name = '%s';
                """ % (opt.app_name, opt.app_server)

    last_logts_sql = """
                SELECT MAX(logts)
                FROM importer_ledger il, data_apps da
                WHERE il.data_app_id = da.data_app_id
                  AND da.app_name = '%s'
                  AND host_name = '%s';
                """ % (opt.app_name, opt.app_server)

    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    try:
        conn = MySQLdb.Connect(host=opt.db_server,
                               user=opt.db_user,
                               passwd=opt.db_passwd,
                               db=opt.db_name)

        nagios_plugins.check_db_schema(conn, 'data_apps', ('state', 'app_name', 'host_name',))
        nagios_plugins.check_db_schema(conn, 'importer_ledger', ('logts',))

    except MySQLdb.OperationalError, e:
        msg = str(e)
        return result, msg
    except nagios_plugins.InvalidDBSchema, e:
        msg = str(e)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            # Get WBNP Importer status
            cursor.execute(state_sql)
            sql_result = cursor.fetchall()

            if not len(sql_result):
                state = None
            else:
                state = sql_result[0][0]

            if state is None or state != 'active':
                result = nagios_plugins.RESULT_CRITICAL
            else:
                # Get the number of phlog files processed by WBNP Importer 
                # within the threshold period from now
                cursor.execute(count_sql % opt.critical_threshold)
                count = cursor.fetchall()[0][0]
                
                if count == 0:
                    result = nagios_plugins.RESULT_CRITICAL
                else:
                    cursor.execute(count_sql % opt.warn_threshold)
                    count = cursor.fetchall()[0][0]
                    
                    if count == 0:
                        result = nagios_plugins.RESULT_WARNING
                    else:
                        result = nagios_plugins.RESULT_OK

            # Get the last log timestamp of phlog files processed by 
            # WBNP Importer
            cursor.execute(last_logts_sql)
            sql_result = cursor.fetchall()

            if not len(sql_result):
                last_logts = None
            else:
                last_logts = sql_result[0][0]               

            msg = build_result_msg(result,
                                   opt.verbosity,
                                   opt.critical_threshold,
                                   opt.warn_threshold,
                                   state,
                                   last_logts)

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
