#!/usr/bin/env python2.6

"""
Nagios plugin for monitoring daemons state. Check is based
on values retrieved from `counters`.
"""

import MySQLdb
import base_nagios_plugin as nagios_plugins
import time
import traceback



_SUPPORTED_OPS = {
    'alert_ts':    {'aggregate': False,
                    'args': ['warn-threshold',
                             'critical-threshold']},
    'check_value': {'aggregate': False,
                    'args': []},
    'check_total': {'aggregate': True,
                    'args': []}}


def make_option_parser():
    """Build a NagiosOptionParser.

    Build and populate NagiosOptionParser with arguments to check
    application counters.
    """
    optp = nagios_plugins.make_option_parser()
    usage = \
"""
%prog -d <db-server> -D <db-name> --db-user=<user> --db-passwd=<password> -a<app_name> -o<operation> -C<counter_name> <operation_options>

options: alert_ts, check_value, check_total

- check_value -a<app_name> -C<counter_name> [--most-recent]
  Check the value of a single counter

- check_total -a<app_name> -C<counter_name>
  Check the accumulated value of the counter across hosts

- alert_ts -a<app_name> -C<counter_name> -w<warning_threshold> -c<critical_threshold> [--most-recent]
  Triggers alert based on the age of the counter


Example:

    python check_counters.py -d <db-server> -D <db-name> --db-user=<user>
            --db-passwd=<password> -a categorization_daemon -o alert_ts
            -C heartbeat -w 3600 -c 7200 -v2 --most-recent

    python check_counters.py -d <db-server> -D <db-name> --db-user=<user>
            --db-passwd=<password> -a categorization_daemon -o check_total
            -C categorization_daemon:domains_processed:dyn -v2
"""
    optp.set_usage(usage)

    optp.add_option('-a', '--app-name', dest='app_name', type='choice',
                    choices=['categorization_daemon', 'domain_importer_daemon'],
                    action='store', help='Application name to be checked: '\
                    '`categorization_daemon` or `domain_importer_daemon`. '\
                    'Default value is not set')

    optp.add_option('-o', '--operation', dest='operation', type='choice',
                    choices=['alert_ts', 'check_total', 'check_value'],
                    action='store',
                    help='Operation to be performed on counters. The '\
                    'following are supported: `check_value`, `check_total`, '\
                    '`alert_ts`. Deafult is not set')

    optp.add_option('-C', '--counter', dest='counter', type='string',
                    action='store', help='Counter name to be checked')

    optp.add_option('-m', '--most-recent', dest='most_recent',
                      default=False, action='store_true',
                      help='Use only most recent counter. This option is '\
                      'ignored with the check_total operation. By default is '\
                      'False')

    return optp


def process_args(optp):
    """Given an option parser, execute it and check options for consistency.

    :Return:
        opt, args
    """
    (opt, args) = optp.parse_args()

    if not opt.db_server:
        raise nagios_plugins.UsageError('db-server is required')

    if opt.verbosity not in (0, 1, 2):
        raise nagios_plugins.UsageError('Verbosity must be 0, 1, or 2')

    if not opt.db_name:
        raise nagios_plugins.UsageError('db_name is required')

    if not opt.app_name:
        raise nagios_plugins.UsageError('app_name is required')

    if not opt.operation:
        raise nagios_plugins.UsageError('operation is required')

    if not opt.counter:
        raise nagios_plugins.UsageError('counter is required')

    if ('warn-threshold' in _SUPPORTED_OPS[opt.operation]['args'] and
            opt.warn_threshold < 1):
        raise nagios_plugins.UsageError('warn_threshold is required for given '\
                              'operation and must be an integer greater than 0')

    if ('critical-threshold' in _SUPPORTED_OPS[opt.operation]['args'] and
          opt.critical_threshold < opt.warn_threshold):
        raise nagios_plugins.UsageError('critical_threshold is required for '\
                 'given operation and must not be less than warn_threshold (%d)'
                  % (opt.warn_threshold,))

    return opt, args


def get_values(optp):
    """Get the current counter values from database.

    :Return:
        [(app_name, hostname, node_id, mtime, value), ...]
    """

    sql = """SELECT app_name, hostname, node_id, UNIX_TIMESTAMP(mtime), value
             FROM counters WHERE counter_name = %s AND app_name =%s
             ORDER BY value DESC
          """


    conn = MySQLdb.Connect(host=optp.db_server, user=optp.db_user,
                           passwd=optp.db_passwd, db=optp.db_name)
    nagios_plugins.check_db_schema(conn, 'counters',
                          ('app_name', 'hostname', 'node_id', 'mtime', 'value'))

    try:
        cursor = conn.cursor()
        try:
            cursor.execute(sql, (optp.counter, optp.app_name))
            rows = cursor.fetchall()
            if rows:
                return rows
            else:
                raise Exception('%s counter for %s does not exist' \
                                % (optp.counter, optp.app_name))
        finally:
            cursor.close()
    finally:
        conn.close()

def check_value(operation, counter, db_values, verbose, most_recent=False):
    """Handle check value operation (check_value, check_total).

    :Parameters:
        - `operation`: operation name
        - `counter`: the counter name which is being checked
        - `db_values`: list of (app_name, hostname, node_id, mtime, value)
                       tuples
        - `most_recent`: only check against the most recent counter.

    :Return:
        nagios_result_status, result_meassage
    """
    messages = []
    total_value = 0
    last_mtime = 0
    op_type_aggregate = _SUPPORTED_OPS[operation]['aggregate']

    for app_name, hostname, node_id, mtime, value in db_values:
        msg = '%s on %s node %s is %s' % (counter, hostname, node_id, value)
        if op_type_aggregate:
            total_value += value
        elif most_recent and mtime > last_mtime:
            last_mtime = mtime
            messages.insert(0, msg)
            continue
        messages.append(msg)
    if op_type_aggregate:
        message = 'the sum of %s on all hosts is %s' % (counter, total_value)
        if verbose:
            message += ('\n' + '\n'.join(messages))
    else:
        message  = '\n'.join(messages)

    return nagios_plugins.RESULT_OK, message


def check_alerts(counter, warning_threshold, critical_threshold,
                 db_values, verbose, most_recent=False):
    """Handle check alerts operations (currently only alert_ts operation).

    :Parameters:
        - `counter`: the counter name which is being checked
        - `warning_threshold`: the warning threshold
        - `critical_threshold`: the critical threshold
        - `db_values`: list of tuples:
                       [(app_name, hostname, node_id, mtime, value),..]
        - `most_recent`: only check against the most recent counter.

    :Return:
        nagios_result_status, result_meassage
    """
    state = nagios_plugins.RESULT_OK
    last_mtime = 0
    messages = []

    for app_name, hostname, node_id, mtime, value in db_values:
        time_diff = int(time.time() - mtime)
        msg = '%s: %s on %s node %s updated %s secs ago' % \
              (app_name, counter, hostname, node_id, time_diff)

        node_state = threshold(time_diff, warning_threshold, critical_threshold)
        if most_recent and mtime > last_mtime:
            last_mtime = mtime
            state = node_state
            messages.insert(0, msg)
        elif not most_recent and node_state > state:
            state = node_state
            messages.insert(0, msg)
        else:
            messages.append(msg)

    message = messages[0]
    if verbose and len(messages) > 1:
        message += ('\n' + '\n'.join(messages[1:]))
    return state, message


def threshold(value, warning_threshold, critical_threshold):
    """Return the state for the given value based on the passed in thresholds.

    :Parameters:
        - `value`: the current counter value
        - `warning_threshold`: the warning threshold
        - `critical_threshold`: the critical threshold

    :Return:
        nagios_result_status
    """
    state = nagios_plugins.RESULT_OK
    if value >= critical_threshold:
        state = nagios_plugins.RESULT_CRITICAL
    elif value >= warning_threshold:
        state = nagios_plugins.RESULT_WARNING
    return state


def main():
    optp = make_option_parser()
    try:
        opt, _ = process_args(optp)
    except nagios_plugins.UsageError as err:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(err))

    try:
        rows = get_values(opt)
    except Exception as exc:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(exc))

    try:
        if opt.operation in ('check_value', 'check_total'):
            result, msg = check_value(opt.operation, opt.counter, rows,
                                      opt.verbosity, opt.most_recent)
        elif opt.operation == 'alert_ts':
            result, msg = check_alerts(opt.counter, opt.warn_threshold,
                          opt.critical_threshold, rows, opt.verbosity,
                          opt.most_recent)
        else:
            # should never be here
            nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR,
                              'Not supported operation: %s' % (opt.operation))
    except Exception as exc:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = 'Exception: %s' % (str(exc),)
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)


if __name__ == '__main__':
    main()

