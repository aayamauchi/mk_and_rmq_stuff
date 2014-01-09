#!/usr/bin/env python2.6

"""
Nagios plugin for monitoring domain importer state. Check is based on either
fails count or last refresh value.

Usage:
    python catbayes_sources_check.py -d <db-server> -D <db-name>
            --db-user <user> --db-passwd <password>
            -w 5 -c 10 -v 1 --mode=fails_count
    python catbayes_sources_check.py -d <db-server> -D <db-name>
            -w 1800 -c 3600 -v 1 --mode=last_refresh

"""

import traceback
import MySQLdb
import base_nagios_plugin as nagios_plugins


def make_option_parser():
    """Build a NagiosOptionParser.

    Build and populate NagiosOptionParser with arguments for checking
    domain importer state.
    """
    optp = nagios_plugins.make_option_parser()

    optp.add_option('--mode', dest='mode', type='choice',
                    choices=['last_refresh', 'fails_count'], action='store',
                    help='Define the way to check status: by `last_refresh`\
                    or `fails_count` value. Default value is not set.\
                    This is mandatory option.')

    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Fails count for `fails_count` mode or time in seconds '\
                    'for `last_refresh` mode for warning. '\
                    'Default value is not set.'

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Fails count for `fails_count` mode or time in seconds '\
                    'for `last_refresh` mode for a critical error. '\
                    'Default value is not set.'

    return optp


def build_result_msg_by_fails(result, fails_count, verbosity,
                     critical_threshold, warn_threshold):
    """Build result message based on fail counts"""

    if result == nagios_plugins.RESULT_CRITICAL:
        base_msg = 'Max fails count exceeds critical threshold on %s.'
        details = ['%s: %d fails' % (counts[1], counts[0])
                   for counts in fails_count if counts[0] > critical_threshold]
        msg = base_msg % (', '.join(details),)

    elif result == nagios_plugins.RESULT_WARNING:
        base_msg = 'Max fails count exceeds warning threshold on %s.'
        details = ['%s: %d fails' % (counts[1], counts[0])
                   for counts in fails_count if counts[0] > warn_threshold]
        msg = base_msg % (', '.join(details),)

    else:
        msg = 'No fails count over threshold.'

    if verbosity == 2:
        src_msg = ['%s: %d' % (counts[1], counts[0])
                    for counts in fails_count]
        msg += ('\nFail counts per source: ' + ', '.join(src_msg))

    return msg


def build_result_msg_by_ts(result, downtime, verbosity,
                     critical_threshold, warn_threshold):
    """Build result message based on idle time check"""

    if result == nagios_plugins.RESULT_CRITICAL:
        base_msg = 'Idle time exceeds critical threshold for %s.'
        details = ['%s: %d sec' % (dt[0], dt[1])
                   for dt in downtime if dt[1] > critical_threshold]
        msg = base_msg % (', '.join(details),)

    elif result == nagios_plugins.RESULT_WARNING:
        base_msg = 'Idle time exceeds warning threshold for %s.'
        details = ['%s: %d sec' % (dt[0], dt[1])
                   for dt in downtime if dt[1] > warn_threshold]
        msg = base_msg % (', '.join(details),)

    else:
        msg = 'No downtime over threshold.'

    if verbosity == 2:
        src_msg = ['%s: %d' % (dt[0], dt[1])
                    for dt in downtime]
        msg += ('\nIdle time per source: ' + ', '.join(src_msg))

    return msg


def check_fail_count(opt):
    """Check fail count per source

    :Return:
        nagios_result_status, result_meassage
    """

    sql = """SELECT fail_count, mnemonic
             FROM domain_sources WHERE enabled=TRUE
             ORDER BY fail_count DESC
          """

    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = 'Script error'
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)
    try:
        nagios_plugins.check_db_schema(conn, 'domain_sources',
                                       ('mnemonic', 'fail_count', 'enabled'))
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

            msg = build_result_msg_by_fails(result, fails_count, opt.verbosity,
                                   opt.critical_threshold, opt.warn_threshold)

        finally:
            cursor.close()
    finally:
        conn.close()

    return result, msg


def check_last_refresh(opt):
    """Check last refresh value per domain source

    The check is performed for enabled sources only.

    :Return:
        nagios_result_status, result_meassage
    """
    sql = """SELECT mnemonic,
             (UNIX_TIMESTAMP() - CAST((last_refresh
                  + refresh_interval) AS SIGNED)) as downtime
             FROM domain_sources
             WHERE enabled = True
             HAVING downtime > 0
             ORDER BY downtime DESC
          """

    result = nagios_plugins.RESULT_SCRIPT_ERROR

    msg = 'Script error'
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)
    try:
        nagios_plugins.check_db_schema(conn, 'domain_sources',
                                       ('mnemonic', 'last_refresh',
                                        'enabled', 'refresh_interval'))
    except nagios_plugins.InvalidDBSchema as err:
        msg = str(err)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            cursor.execute(sql)
            downtime = cursor.fetchall()
            if len(downtime) == 0:
                result = nagios_plugins.RESULT_OK
                msg = 'No downtime over threshold.'
                return result, msg

            if downtime[0][1] > opt.critical_threshold:
                result = nagios_plugins.RESULT_CRITICAL
            elif downtime[0][1] > opt.warn_threshold:
                result = nagios_plugins.RESULT_WARNING
            else:
                result = nagios_plugins.RESULT_OK

            msg = build_result_msg_by_ts(result, downtime, opt.verbosity,
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
        if not opt.mode:
            raise nagios_plugins.UsageError('--mode option is required. '\
                      'Possible values are `last_refresh`, `fails_count`')
    except nagios_plugins.UsageError as err:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(err))

    try:
        if opt.mode == 'last_refresh':
            result, msg = check_last_refresh(opt)
        elif opt.mode == 'fails_count':
            result, msg = check_fail_count(opt)
    except Exception as exc:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = 'Exception: %s' % (str(exc),)
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)


if __name__ == '__main__':
    main()

