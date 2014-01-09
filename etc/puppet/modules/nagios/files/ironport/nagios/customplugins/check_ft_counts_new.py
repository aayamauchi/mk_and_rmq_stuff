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
import _mysql_exceptions

_STATE_VAL = {'OK': 0,
              'WARNING': 1,
              'CRITICAL': 2,
              'ERROR': 3}

_SUPPORTED_OPS = {
    'alert_ts':    {'aggregate': False,
                    'args': ['warning_threshold',
                             'critical_threshold']},
    'alert_value': {'aggregate': False,
                    'args': ['warning_threshold',
                             'critical_threshold']},
    'alert_total': {'aggregate': True,
                    'args': ['warning_threshold',
                             'critical_threshold']},
    'check_value': {'aggregate': False,
                    'args': []}}

def get_values(db_dict, counter, lower_bound=False):
    """Get the current counter values from the FT database.

    :param db_dict: a dictionary storing the database connection parameters
    :param counter: the name of the counter to check
    :param lower_bound: specifies the sorting order for multiple return values

    :returns: [(value, node_name, mtime, hostname, pid), ...]"""
    conn = MySQLdb.connect(**db_dict)
    if lower_bound:
        asc_desc='ASC'
    else:
        asc_desc='DESC'
    try:
        cursor = conn.cursor()
        try:
            try:
                cursor.execute("""SELECT value, node_name, mtime, hostname, c.pid
                                  FROM ft_counts c
                                  LEFT JOIN heartbeats h
                                  ON c.node_name=h.master
                                  WHERE counter_name = %%s
                                  ORDER BY value %s""" % (asc_desc), counter)

            except _mysql_exceptions.ProgrammingError:
                cursor.execute("""SELECT value, node_name, mtime, hostname, pid
                        FROM ft_counts
                        WHERE counter_name = %%s
                        ORDER BY value %s""" % (asc_desc), counter)


            rows = cursor.fetchall()

            # This is needed to handle Empty results returned by SQL query
            if str(type(rows)).split("'")[1] == 'tuple' and len(rows) == 0:
                del rows
                rows = ((0L, " ", 0L, " ", 0L),)

            if rows:
                return rows
            else:
                raise Exception, '%s does not exist' % counter
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
"""check_ft_counts [options] <db_host> <db_user> <db_password> <db_name> operation <operation_parameters>

operation: check_value | alert_value | alert_ts | alert_total

- check_value <counter_name>
- alert_value <counter_name> <warning_threshold> <alert_threshold>
  Triggers alert based on the value of the counter

- alert_ts <counter_name> <warning_threshold> <alert_threshold>
  Triggers alert based on the age of the counter

- alert_total <counter_name> <warning_threshold> <alert_threshold>
  Triggers alert based on the accumulated value of the counter across
  hosts)"""
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
                      'switching primary hosts.')
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

def check_value(operation, counter, ft_counts_values, lower_bound=False,
                most_recent=False):
    """Handle check value operation.

    :param operation: operation name
    :param counter: the counter name which is being checked
    :param warning_threshold: the warning threshold
    :param critical_threshold: the critical threshold
    :param ft_counts_values: list of (value, node_name, mtime, hostname, pid)
    tuples
    :param lower_bound: is the check against a lower bound threshold?
    :param most_recent: only check against the most recent counter.

    :returns: ('OK', values, basic message, verbose message)"""
    messages = []
    values = []
    last_mtime = 0
    for value, node_name, mtime, hostname, pid in ft_counts_values:
        msg = '%s on %s is %s' % (counter, node_name, value)
        messages.append(msg)
        if most_recent:
            if mtime > last_mtime:
                last_mtime = mtime
                values = [(node_name, value)]
        else:
            values.append((node_name, value))
    verbose_msg = '\n'.join(messages[1:])
    return 'OK', values, messages[0], verbose_msg

def check_alerts(operation, counter, warning_threshold, critical_threshold,
                 ft_counts_values, lower_bound=False, most_recent=False):
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
    sum_value = 0
    last_mtime = 0
    messages = []
    values = []
    op_type_aggregate = _SUPPORTED_OPS[operation]['aggregate']

    for value, node_name, mtime, hostname, pid in ft_counts_values:
        if operation == 'alert_value':
            msg = '%s on %s is %s' % (counter, node_name, value)
        elif operation == 'alert_ts':
            value = int(time.time() - mtime)
            msg = '%s on %s updated %s secs ago' % (counter, node_name, value)
        elif operation == 'alert_total':
            op_type_aggregate = True
            sum_value += value
            msg = '%s on %s is %s' % (counter, node_name, value)
        else:
            # should never come here
            exit_error('invalid operaiton: %s' % operation)
        if op_type_aggregate is False:
            node_state = threshold(value, warning_threshold,
                                   critical_threshold, lower_bound)
            if most_recent and mtime > last_mtime:
                last_mtime = mtime
                state = node_state
                messages.insert(0, msg)
                values.insert(0, (node_name, value))
                continue
            elif not most_recent:
                if _STATE_VAL[node_state] > _STATE_VAL[state]:
                    state = node_state
        messages.append(msg)
        values.append((node_name, value))

    if op_type_aggregate is True:
        state = threshold(sum_value, warning_threshold, critical_threshold,
                          lower_bound)
        msg = 'total %s on %s is %s' % (counter, node_name, sum_value)
        messages.insert(0, msg)
        values = [(node_name, value)]

    basic_msg = '%s - %s' % (state, messages[0])
    verbose_msg = '\n'.join(messages[1:])
    return state, values, basic_msg, verbose_msg

def main():

    db_dict, op_dict = parse_argv()

    try:
        rows = get_values(db_dict, op_dict['counter'], op_dict['options'].lower_bound)
    except MySQLdb.Error, e:
        exit_error('Mysql connection error: %s' % (e[1],))
    except Exception, e:
        exit_error(e)

    if op_dict['op'] == 'check_value':
        state, values, basic_msg, verbose_msg = \
            check_value(op_dict['op'], op_dict['counter'], rows,
                        op_dict['options'].lower_bound,
                        op_dict['options'].most_recent)
    else:
        state, values, basic_msg, verbose_msg = \
            check_alerts(op_dict['op'], op_dict['counter'],
                         int(op_dict['args']['warning_threshold']),
                         int(op_dict['args']['critical_threshold']), rows,
                         op_dict['options'].lower_bound,
                         op_dict['options'].most_recent)
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
