#!/usr/bin/python26
"""
    retrieve values from ft_counts table.
    This is created as a separate script to minize the
    dependence on common packages so it can be
    easily used by SysOps
"""

import optparse
import sys
import time

import MySQLdb

_STATE_VAL = {'OK': 0,
              'WARNING': 1,
              'CRITICAL': 2,
              'ERROR': 3}

_SUPPORTED_OPS = {
    'alert_ts':    {'pattern': 'ts',
                    'args': ['warning_threshold', 'critical_threshold']},
    'alert_value': {'pattern': 'value',
                    'args': ['warning_threshold', 'critical_threshold']},
    'alert_rate':  {'pattern': 'rate',
                    'args': ['warning_threshold', 'critical_threshold']},
    'check_ts':    {'pattern': 'ts',
                    'args': []},
    'check_value': {'pattern': 'value',
                    'args': []},
    'check_rate':  {'pattern': 'rate',
                    'args': []},
}

_PATTERNS = {
    'ts': '^%s:ts$',
    'value': '^%s:(dyn|st)$',
    'rate': '^%s:r[0-9]+$',
}


def get_values(db_dict, counter, pattern, lower_bound=False):
    """Get the current counter values from the counts database.

    :param db_dict: a dictionary storing the database connection parameters
    :param counter: the name of the counter to check
    :param pattern: (ts|value|rate)
    :param lower_bound: specifies the sorting order for multiple return values

    :returns: [(value, node_name, mtime, hostname), ...]"""
    conn = MySQLdb.connect(**db_dict)
    if lower_bound:
        asc_desc='ASC'
    else:
        asc_desc='DESC'
    try:
        cursor = conn.cursor()
        try:
            counter_pattern = _PATTERNS[pattern] % (counter,)
            sql = """\
                SELECT value, mtime, sds_hostname
                FROM sds_counters
                WHERE name RLIKE %%s
                ORDER BY value %s""" % (asc_desc)
            cursor.execute(sql, counter_pattern)
            rows = cursor.fetchall()
            if rows:
                return rows
            else:
                raise Exception('%s does not exist' % (counter,))
        finally:
            cursor.close()
    finally:
        conn.close()

def exit_error(error_str=None):
    """Print an error message and return an error return code.

    :param error_str: error message"""
    if error_str:
        print 'ERROR - %s\n' % (error_str,)
    print usage()
    sys.exit(_STATE_VAL['ERROR'])

def print_output(values, basic_message, verbose_message=None, cacti=False,
                 verbose=False):
    """Print the appropriate output to standard out.

    :param values: list of node_name, value tuples
    :param basic_message: one line message (compatible with Nagios)
    :param verbose_message: multi-line verbose message
    :param cacti: output cacti compatible message
    :param verbose: print verbose_message if available"""
    if not cacti:
        print basic_message
        if verbose and verbose_message:
            print verbose_message
    else:
        if len(values) == 1:
            print values[0][1]
        else:
            # <node_name1>:<value1> <node_name2>:<value2> ... \n
            print ' '.join([ '%s:%s' % (n, v) for n, v in values ])

def usage():
    usage = \
"""check_counts [options] <db_host> <db_user> <db_password> <db_name> operation <operation_parameters>

operation: check_value | check_rate | check_ts | alert_value | alert_rate | alert_ts

- check_value <counter_name>
  Check the value of the dynamic or static counter

- check_rate <counter_name>
  Check the rate of the dynamic counter

- check_ts <counter_name>
  Check the value of the timestamp counter

- alert_value <counter_name> <warning_threshold> <alert_threshold>
  Triggers alert based on the value of the counter

- alert_rate <counter_name> <warning_threshold> <alert_threshold>
  Triggers alert based on the rate of the counter

- alert_ts <counter_name> <warning_threshold> <alert_threshold>
  Triggers alert based on the age of the timestamp counter"""
    return usage

def parse_argv():
    """Setup the option parser, and parse the results

    :returns: db_dict, op_dict"""
    db_dict = {}
    op_dict = {}

    parser = optparse.OptionParser(usage())
    parser.add_option('-l', '--lower-bound', dest='lower_bound',
                      default=False, action='store_true',
                      help='Use lower bounds for operations thresholds.')
    parser.add_option('-m', '--most-recent', dest='most_recent',
                      default=False, action='store_true',
                      help='Use only most recent counter. Useful for single-on '
                      'FT applicaitions which may leave a stale counter after '
                      'switching primary hosts. This option is ignored with the '
                      'check_total operation.')
    parser.add_option('-t', '--total', dest='total',
                      default=False, action='store_true',
                      help='Values and alerts are based on the accumulated value '
                           'of the counter across all hosts')
    parser.add_option('-c', '--cacti', dest='cacti',
                      default=False, action='store_true',
                      help='Cacti compatible output only.')
    parser.add_option('-v', '--verbose', dest='verbose',
                      default=False, action='store_true',
                      help='Verbose, multi-line output. Incompatible with '
                      '--cacti.')

    (options, args) = parser.parse_args()

    if len(args) < 6:
        exit_error('Missing required arguments.')

    basic_args = args[:6]
    op_args = args[6:]
    db_host, db_user, db_password, db_name, op, counter = basic_args
    db_dict.update({'host': db_host, 'user': db_user,
                    'passwd': db_password, 'db': db_name})
    if len(op_args) != len(_SUPPORTED_OPS[op]['args']):
        exit_error('The following arguments are requred: %s' % (
                   _SUPPORTED_OPS[op]['args']))
    args_dict = dict(zip(_SUPPORTED_OPS[op]['args'], op_args))
    if options.verbose and options.cacti:
        exit_error('The verbose and cacti options are mutually exclusive.')
    op_dict.update({'op': op, 'counter': counter, 'args': args_dict,
                    'options': options})

    if not op in _SUPPORTED_OPS and \
        not len(op_args) == len(_SUPPORTED_OPS[op]['args']):
        exit_error('Invalid parameters')
    return db_dict, op_dict

def threshold(value, warning_threshold, alert_threshold, lower_bound=False):
    """Return the state for the given value based on the passed in thresholds.

    :param value: the current counter value
    :param warning_threshold: the warning threshold
    :param alert_threshold: the critical threshold
    :param lower_bound: are the thresholds an upper or lower bound

    :returns: 'OK'|'WARNING'|'CRITICAL'"""
    state = 'OK'
    if lower_bound is False:
        if value >= alert_threshold:
            state = 'CRITICAL'
        elif value >= warning_threshold:
            state = 'WARNING'
    else:
        if value <= alert_threshold:
            state = 'CRITICAL'
        elif value <= warning_threshold:
            state = 'WARNING'
    return state

def check_value(operation, counter, count_values, lower_bound=False,
                most_recent=False, aggregate=False):
    """Handle check value operation.

    :param operation: operation name
    :param counter: the counter name which is being checked
    :param count_values: list of (value, node_name, mtime, hostname, pid)
    tuples
    :param lower_bound: is the check against a lower bound threshold?
    :param most_recent: only check against the most recent counter.
    :param aggregate: if multiple results, should they be summed together.

    :returns: ('OK', values, basic message, verbose message)"""
    messages = []
    values = []
    last_mtime = 0
    for value, mtime, hostname in count_values:
        if operation in ['check_value', 'check_rate']:
            msg = '%s on %s is %s' % (counter, hostname, value)
        elif operation == 'check_ts':
            ts = value
            value = int(time.time()) - int(value)
            msg = '%s on %s is %s (%s secs ago)' % (
                counter, hostname, ts, value)
        else:
            # should never come here
            exit_error('invalid operation: %s' % operation)
        messages.append(msg)
        if aggregate:
            if not values:
                values = [('aggregate', value)]
            else:
                values = [('aggregate', values[0][1] + value)]
        elif most_recent:
            if mtime > last_mtime:
                last_mtime = mtime
                values = [(hostname, value)]
        else:
            values.append((hostname, value))
    verbose_msg = '\n'.join(messages[1:])
    if aggregate:
        message = 'the sum of %s on all hosts is %s' % (counter, values[0][1])
    else:
        message = messages[0]
    return 'OK', values, message, verbose_msg

def check_alerts(operation, counter, warning_threshold, critical_threshold,
                 count_values, lower_bound=False, most_recent=False,
                 aggregate=False):
    """Handle check alerts operations (alert_value, alert_ts, alert_total).

    :param operation: operation name
    :param counter: the counter name which is being checked
    :param warning_threshold: the warning threshold
    :param critical_threshold: the critical threshold
    :param ft_counts_values: list of (value, node_name, mtime, hostname, pid)
    tuples
    :param lower_bound: is the check against a lower bound threshold?
    :param most_recent: only check against the most recent counter.

    :returns: ('OK'|'WARNING'|'CRITICAL', values, basic message, verbose message)"""
    state = 'OK'
    last_mtime = 0
    messages = []
    values = []

    for value, mtime, hostname in count_values:
        if operation in ['alert_value', 'alert_rate']:
            msg = '%s on %s is %s' % (counter, hostname, value)
        elif operation == 'alert_ts':
            ts = value
            value = int(time.time()) - int(value)
            msg = '%s on %s is %s (%s secs ago)' % (
                counter, hostname, ts, value)
        else:
            # should never come here
            exit_error('invalid operation: %s' % operation)
        if not aggregate:
            node_state = threshold(value, warning_threshold,
                                   critical_threshold, lower_bound)
            if most_recent and mtime > last_mtime:
                last_mtime = mtime
                state = node_state
                messages.insert(0, msg)
                values.insert(0, (hostname, value))
                continue
            elif not most_recent:
                if _STATE_VAL[node_state] > _STATE_VAL[state]:
                    state = node_state
        messages.append(msg)
        values.append((hostname, value))

    if aggregate:
        sum_value = sum([x[1] for x in values])
        state = threshold(sum_value, warning_threshold, critical_threshold,
                          lower_bound)
        msg = 'total %s on %s is %s' % (counter, hostname, sum_value)
        messages.insert(0, msg)
        values = [(hostname, sum_value)]

    basic_msg = '%s - %s' % (state, messages[0])
    verbose_msg = '\n'.join(messages[1:])
    return state, values, basic_msg, verbose_msg

def main():

    db_dict, op_dict = parse_argv()

    try:
        pattern = _SUPPORTED_OPS[op_dict['op']]['pattern']
        rows = get_values(db_dict, op_dict['counter'], pattern,
                          lower_bound=op_dict['options'].lower_bound)
    except MySQLdb.Error, e:
        exit_error('Mysql connection error: %s' % (e[1],))
    except Exception, e:
        exit_error(e)

    if op_dict['op'] in ['check_value', 'check_rate', 'check_ts']:
        state, values, basic_msg, verbose_msg = \
            check_value(op_dict['op'], op_dict['counter'], rows,
                        lower_bound=op_dict['options'].lower_bound,
                        most_recent=op_dict['options'].most_recent,
                        aggregate=op_dict['options'].total)
    else:
        state, values, basic_msg, verbose_msg = \
            check_alerts(op_dict['op'], op_dict['counter'],
                         int(op_dict['args']['warning_threshold']),
                         int(op_dict['args']['critical_threshold']), rows,
                         lower_bound=op_dict['options'].lower_bound,
                         most_recent=op_dict['options'].most_recent,
                         aggregate=op_dict['options'].total)
    print_output(values, basic_msg, verbose_msg, cacti=op_dict['options'].cacti,
                 verbose=op_dict['options'].verbose)
    return _STATE_VAL[state]

if __name__ == '__main__':
    ret_code = _STATE_VAL['ERROR']
    try:
        ret_code = main()
    except SystemExit:
        pass
    except:
        import traceback
        traceback.print_exc()
        ret_code = _STATE_VAL['ERROR']
    sys.exit(ret_code)
