#!/usr/bin/env python26
"""Simple script to check to see if an FT process is restarting too often.

This is created as a separate script to avoid depending on common modules so it
can be easily used by SysOps.

:Author: duncan
:Status: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_ft_restarts.py#1 $
"""

import sys
import time

import MySQLdb

# Nagios-compatible exit codes.
EX_OK = 0
EX_WARN = 1
EX_CRITICAL = 2
EX_UNKNOWN = 3

OP_CHECK = 'check'
OP_ALERT = 'alert'

USAGE = r"""
Usage: check_ft_restarts.py <db_host> <db_user> <db_password> <db_name> \
           <operation> <app_name> <cluster_name> <time_period_in_sec> \
           [<warning_thresold> <critical_threshold>]

   operation: check | alert

   - check <app_name> <cluster_name> <time_period_in_sec>
     returns info about service starts in the given time period

   - alert <app_name> <cluster_name> <time_period_in_sec> <warning_threshold> \
         <critical_threshold>
     compare the number of starts in the time period to the thresholds
""".strip()


def parse_argv(argv):
    """Parses command line args.

    :Returns:
        (operation, db_params, (app_name, cluster_name, period),
        (warning_threshold, critical_threshold))
    """

    if len(argv) < 9:
        print 'Not enough parameters!'
        print ''
        print USAGE
        sys.exit(EX_UNKNOWN)

    (db_host, db_user, db_password, db_name, operation, app_name, cluster_name,
     period) = argv[1:9]
    thresholds = argv[9:]

    if not ((operation == OP_CHECK and len(thresholds) == 0)
            or (operation == OP_ALERT and len(thresholds) == 2)):
        print 'Invalid parameters!'
        print ''
        print USAGE
        sys.exit(EX_UNKNOWN)

    db_params = dict(host=db_host, user=db_user, passwd=db_password,
                     db=db_name)
    try:
        thresholds = [int(t) for t in thresholds]
        period = int(period)
    except ValueError:
        print 'Period and thresholds must be integers.'
        print ''
        print USAGE
        sys.exit(EX_UNKNOWN)

    return (operation, db_params, (app_name, cluster_name, period),
            thresholds)


def get_connection(db_params):
    return MySQLdb.connect(**db_params)


def get_data(db_params, search_params):
    conn = get_connection(db_params)
    try:
        c = conn.cursor()
        try:
            app_name, cluster_name, period = search_params

            # Check to see if the ft_node_events table is truncated in our time
            # period, by checking to see if there are events *before* our time
            # period in the table.
            truncated = False
            c.execute(
                'SELECT event_id FROM ft_node_events '
                'WHERE event_ts < UNIX_TIMESTAMP() - %s '
                'LIMIT 1',
                (period,))
            data = c.fetchone()
            if data is None:
                truncated = True

            # We have to assume that the app and DB timestamps are mostly in
            # sync.  Get all data from the table.
            c.execute('SELECT node_name, event_ts, event_details '
                      'FROM ft_node_events '
                      'WHERE app_name = %s AND cluster_name = %s AND '
                      '    event_ts >= UNIX_TIMESTAMP() - %s AND '
                      '    event = "started service" '
                      'ORDER BY event_id ASC',
                      (app_name, cluster_name, period))
            return (c.fetchall(), truncated)
        finally:
            c.close()
    finally:
        conn.close()


def print_status(db_params, search_params):
    """Print status about last restarts."""
    data, truncated = get_data(db_params, search_params)

    for node_name, ts, details in data:
        print '| %s | %-45s | %-30s |' % (time.ctime(ts), node_name, details)

    if truncated:
        print 'End of available data reached.'


def alert(db_params, search_params, thresholds):
    """Check restart count."""
    data, truncated = get_data(db_params, search_params)
    app_name, cluster_name, period = search_params

    warn, crit = thresholds

    num_restarts = len(data)

    if num_restarts >= crit:
        print 'CRITICAL: %d restarts in %d seconds.' % (num_restarts, period)
        return EX_CRITICAL
    elif num_restarts >= warn:
        print 'WARNING: %d restarts in %d seconds.' % (num_restarts, period)
        return EX_WARN
    elif truncated:
        print 'UNKNOWN: ft_node_status table goes back less than %d ' \
              'seconds. %d restarts in table.' % (period, num_restarts)
        return EX_UNKNOWN
    else:
        print 'OK: %d restarts in %d seconds.' % (num_restarts, period)
        return EX_OK


if __name__ == '__main__':
    exit_code = 0
    operation, db_params, search_params, thresholds = parse_argv(sys.argv)
    if operation == OP_CHECK:
        print_status(db_params, search_params)
    elif operation == OP_ALERT:
        exit_code = alert(db_params, search_params, thresholds)
    else:
        assert AssertionError('Invalid operation!')
    sys.exit(exit_code)

