#!/usr/bin/python26
"""
Nagios plugin for monitoring downtime of categorization daemons.

Usage:
    python26 catbayes_cluster_check.py -d <db-server> -D <db-name> 
            --db-user <user> --db-passwd <password> -w 1800 -c 3600 -v 1
    python26 catbayes_cluster_check.py -d <db-server> -D <db-name>

"""

import traceback
import MySQLdb
import base_nagios_plugin as nagios_plugins

DEFAULT_WARN_THRESHOLD     = 1800
DEFAULT_CRITICAL_THRESHOLD = 3600

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking whether
    catbayes daemon is running.
    """
    optp = nagios_plugins.make_option_parser()

    opt_warn = optp.get_option('-w')
    opt_warn.help='Daemon downtime for warning. ' + \
                  'Default: %d' % DEFAULT_WARN_THRESHOLD

    opt_crit = optp.get_option('-c')
    opt_crit.help='Daemon downtime for a critical error. ' + \
                  'Default: %d' % DEFAULT_CRITICAL_THRESHOLD


    optp.set_defaults(warn_threshold=DEFAULT_WARN_THRESHOLD,
                      critical_threshold=DEFAULT_CRITICAL_THRESHOLD)

    return optp


def build_result_msg(result, downtime, verbosity,
                     critical_threshold, warn_threshold):
    res_map = {nagios_plugins.RESULT_CRITICAL: ' Critical threshold = %s'\
                                                % (critical_threshold,),
               nagios_plugins.RESULT_WARNING: ' Warning threshold = %s' \
                                               % (warn_threshold,),
               nagios_plugins.RESULT_OK: ' Idle time is not over threshold'
              }
    msg = 'Last categorization was performed %d sec ago.' % (downtime, )
    if verbosity > 0:
        msg += res_map[result]
    return msg


def check_last_catagorized_mtime(opt, args):

    sql = """SELECT UNIX_TIMESTAMP() - UNIX_TIMESTAMP(MAX(mtime))
             FROM catbayes_results
             WHERE state IN ('categorized', 'error')
          """

    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)
    try:
        nagios_plugins.check_db_schema(conn, 'catbayes_results',
                                       ('mtime', 'state'))
    except nagios_plugins.InvalidDBSchema, e:
        msg = str(e)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            cursor.execute(sql)
            downtime = cursor.fetchall()[0][0]

            if downtime > opt.critical_threshold:
                result = nagios_plugins.RESULT_CRITICAL
            elif downtime > opt.warn_threshold:
                result = nagios_plugins.RESULT_WARNING
            else:
                result = nagios_plugins.RESULT_OK

            msg = build_result_msg(result, downtime, opt.verbosity,
                                   opt.critical_threshold, opt.warn_threshold)

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
        result, msg = check_last_catagorized_mtime(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)


if __name__ == '__main__':
    main()

