#!/usr/bin/python26
"""
    Checks the growth rate of a counter (ft) stored in mysql.
    This script is a modification of check_ft_counts_new.py.
    It currently only supports one operation: alert_rate, but
    other variations could be added without much hassle.
"""

import optparse
import sys
import time
import simplejson
import stat
import MySQLdb

_STATE_VAL = {'OK': 0,
              'WARNING': 1,
              'CRITICAL': 2,
              'ERROR': 3}

_SUPPORTED_OPS = {
    'alert_rate': {'aggregate': True,
                    'args': ['interval',
                             'warning_threshold',
                             'critical_threshold']}}

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
            cursor.execute("""SELECT value, node_name, mtime, hostname, pid
                    FROM ft_counts
                    WHERE counter_name = %%s
                    ORDER BY value %s""" % (asc_desc), counter)

            rows = cursor.fetchall()
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

def print_output(rate, msg, verbose_message=None, cacti=False,
                 verbose=False):
    """Print the appropriate output to standard out.

    :param rate: current rate
    :param msg: one line message (compatible with Nagios)
    :param verbose_message: multi-line verbose message
    :param cacti: output cacti compatible message
    :param verbose: print verbose_message if available"""
    if not cacti:
        print msg
        if verbose and verbose_message:
            print verbose_message
    else:
        print rate

def usage():
    usage = \
"""check_ft_count_rate [options] <db_host> <db_user> <db_password> <db_name> operation <operation_parameters>

operation (currently only one): alert_rate

- alert_rate <counter_name> <interval> <warning_threshold> <alert_threshold>
  Triggers alert based on the rate of growth of the counter over interval (seconds)."""
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
                      'FT applications which may leave a stale counter after '
                      'switching primary hosts. Default is to sum all values.')
    parser.add_option('-c', '--cacti', dest='cacti',
                      default=False, action='store_true',
                      help='Cacti compatible output only.')
    parser.add_option('-v', '--verbose', dest='verbose',
                      default=False, action='store_true',
                      help='Verbose (CURRENTLY DISABLED), multi-line output. Incompatible with '
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


# format:
# { 'counter' : #, 'value' : #, 'timestamp' : # }
def read_file(host, counter):
    try:
        cache = open('/tmp/tmp_Nagios_ft_rate.%s:%s' % (host, counter), 'r')
    except:
        return None
    else:
        cachedata = cache.read()
        cachedata = simplejson.loads(cachedata)
        return cachedata

def write_file(host, counter, cachedata):
    file = '/tmp/tmp_Nagios_ft_rate.%s:%s' % (host, counter)
    try:
        cache = open(file, 'w')
    except:
        print "Unable to write cache file"
        sys.exit(3)
    else:
        cache.write(simplejson.dumps(cachedata))
    cache.close()
    try:
    	os.chown(file, os.geteuid, -1)
    	os.chmod(file, stat.S_IRUSR| stat.S_IRGRP | stat.S_IROTH | stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH )
    except:
    	x = 1


def check_alerts(db_dict, operation, counter, interval, warning_threshold, critical_threshold,
                 ft_counts_values, lower_bound=False, most_recent=False):
    """Handle check alerts operations, currently only one: alert_rate.

    :param db_dict: a dictionary storing the database connection parameters
    :param operation: operation name
    :param counter: the counter name which is being checked
    :param interval: time interval in seconds over which to base the rate on
    :param warning_threshold: the warning threshold
    :param critical_threshold: the critical threshold
    :param ft_counts_values: list of (value, node_name, mtime, hostname, pid) tuples
    :param lower_bound: is the check against a lower bound threshold?
    :param most_recent: only check against the most recent counter.

    :returns: ('OK'|'WARNING'|'CRITICAL', values, basic message, verbose message)"""
    state = 'OK'
    cur_val_to_check = 0
    last_mtime = 0
    rate = 0
    op_type_aggregate = _SUPPORTED_OPS[operation]['aggregate']

    #
    # Iterate over all node values, summing or selecting the most recent as appropriate
    #
    for value, node_name, mtime, hostname, pid in ft_counts_values:
        if operation == 'alert_rate':
            if op_type_aggregate is True:
                cur_val_to_check += value
            else:
                if most_recent and mtime > last_mtime:
                    last_mtime = mtime
                    cur_val_to_check = value
                    continue
        else:
            # should never come here
            exit_error('invalid operation: %s' % operation)

    #
    # Calculate rate and obtain state
    #
    if operation == 'alert_rate':
        nowdata = { 'counter' : counter, 'value' : cur_val_to_check, 'timestamp' : int(time.time()) }
        cachedata = read_file(db_dict['host'], counter)

        if not cachedata:
            write_file(db_dict['host'], counter, [nowdata, nowdata])
            exit_error("First run, nothing to compare against")

        for line in cachedata:
            if line['timestamp'] < (nowdata['timestamp'] - interval):
                write_file(db_dict['host'], counter, [nowdata, line])
                rate = int((float(cur_val_to_check - line['value']) / float(float(nowdata['timestamp'] - line['timestamp']) / interval) + 0.5))
                state = threshold(rate, warning_threshold, critical_threshold, lower_bound)
                msg = '%s - growth rate is %s (per %s second interval)' % (state, rate, interval)
                return rate, state, msg
    else:
        # should never come here
        exit_error('invalid operation: %s' % operation)

def main():

    db_dict, op_dict = parse_argv()

    try:
        rows = get_values(db_dict, op_dict['counter'], op_dict['options'].lower_bound)
    except MySQLdb.Error, e:
        exit_error('Mysql connection error: %s' % (e[1],))
    except Exception, e:
        exit_error(e)

    rate, state, msg = \
        check_alerts(db_dict, op_dict['op'], op_dict['counter'],
                     int(op_dict['args']['interval']),
                     int(op_dict['args']['warning_threshold']),
                     int(op_dict['args']['critical_threshold']), rows,
                     op_dict['options'].lower_bound,
                     op_dict['options'].most_recent)
    print_output(rate, msg, verbose_message=None, cacti=op_dict['options'].cacti,
                 verbose=False)
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
