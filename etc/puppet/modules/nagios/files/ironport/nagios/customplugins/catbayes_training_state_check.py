#!/usr/bin/env python2.6

"""
Nagios plugin for monitoring training state (fails count).

Usage:
    python catbayes_training_state_check.py -d <db-server> -D <db-name>
            --db-user <user> --db-passwd <password> -w 5 -c 10 -v 1
    python catbayes_training_state_check.py -d <db-server> -D <db-name>

"""

import traceback
import MySQLdb
import base_nagios_plugin as nagios_plugins

DEFAULT_WARN_THRESHOLD     = 5
DEFAULT_CRITICAL_THRESHOLD = 10

def make_option_parser():
    """Build a NagiosOptionParser

    Build NagiosOptionParser and populate it with arguments for checking
    fails count in training.
    """
    optp = nagios_plugins.make_option_parser()
    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Fails count for warning. ' + \
                    'Default: %d' % (DEFAULT_WARN_THRESHOLD,)

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Fails count for a critical error. ' + \
                    'Default: %d' % (DEFAULT_CRITICAL_THRESHOLD,)

    optp.set_defaults(warn_threshold=DEFAULT_WARN_THRESHOLD,
                      critical_threshold=DEFAULT_CRITICAL_THRESHOLD)
    return optp


def build_result_msg(result, fails_count, verbosity,
                     critical_threshold, warn_threshold):
    """Build and return result message"""

    if result == nagios_plugins.RESULT_CRITICAL:
        base_msg = 'Max fails count exceeds critical threshold for %s.'
        details = ['%s: %d fails' % (counts[1], counts[0])
                   for counts in fails_count if counts[0] > critical_threshold]
        msg = base_msg % (', '.join(details),)

    elif result == nagios_plugins.RESULT_WARNING:
        base_msg = 'Max fails count exceeds warning threshold for %s.'
        details = ['%s: %d fails' % (counts[1], counts[0])
                   for counts in fails_count if counts[0] > warn_threshold]
        msg = base_msg % (', '.join(details),)

    else:
        msg = 'No fails count over threshold.'

    if verbosity == 2:
        src_msg = ['%s: %d' % (counts[1], counts[0])
                    for counts in fails_count]
        msg += ('\nFail counts per language: ' + ', '.join(src_msg))

    return msg


def check_fail_count(opt):
    """Check training fail count per language

    The check is performed for enabled languages only.
    :Return:
        nagios_result_status, result_meassage
    """

    sql = """SELECT fail_count, language
             FROM training_state WHERE enabled=TRUE
             ORDER BY fail_count DESC
          """

    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = 'Script error'
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)
    try:
        nagios_plugins.check_db_schema(conn, 'training_state',
                                       ('fail_count', 'language', 'enabled'))
    except nagios_plugins.InvalidDBSchema as err:
        msg = str(err)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            cursor.execute(sql)
            fails_count = cursor.fetchall()
            if len(fails_count) == 0:
                result = nagios_plugins.RESULT_OK
                msg = 'No fails count over threshold.'
                return result, msg

            if fails_count[0][0] > opt.critical_threshold:
                result = nagios_plugins.RESULT_CRITICAL
            elif fails_count[0][0] > opt.warn_threshold:
                result = nagios_plugins.RESULT_WARNING
            else:
                result = nagios_plugins.RESULT_OK

            msg = build_result_msg(result, fails_count, opt.verbosity,
                                   opt.critical_threshold, opt.warn_threshold)

        finally:
            cursor.close()
    finally:
        conn.close()

    return result, msg


def main():
    optp = make_option_parser()
    try:
        opt, _ = nagios_plugins.process_args(optp)
    except nagios_plugins.UsageError as err:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(err))

    try:
        result, msg = check_fail_count(opt)
    except Exception as exc:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = 'Exception: %s' % (str(exc),)
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)


if __name__ == '__main__':
    main()
