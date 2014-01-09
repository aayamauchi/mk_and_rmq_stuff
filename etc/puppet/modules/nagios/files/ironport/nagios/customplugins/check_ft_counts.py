#!/usr/bin/python26
"""
    retrieve values from ft_counts table.
    This is created as a separate script to minize the 
    dependence on common packages so it can be
    easily used by SysOps
"""

import sys
import time

from optparse import OptionParser

import MySQLdb

db_host = ''
db_user = ''
db_password = '' 
db_name = ''
operation = ''
counter_name = ''
operation_params = []
lower_bound = False

def connect_db():
    return MySQLdb.connect(host=db_host, user=db_user, passwd=db_password, db=db_name)

def get_values():
    conn = connect_db()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute("""SELECT value, node_name, mtime, mby, hostname, pid
                    FROM ft_counts
                    WHERE counter_name = %s""", counter_name)
    
            rows = cursor.fetchall()
            if rows:
                return rows
            else:
                raise Exception, '%s does not exist' % counter_name
        finally:
            cursor.close()
    finally:
        conn.close()

def usage():
    usage = ''
    usage += 'usage: check_ft_counts [options] operation <operation_parameters>\n'
    usage += '\n'
    usage += 'usage (deprecated): check_ft_counts <db_host> <db_user> <db_password> <db_name> operation <operation_parameters>\n'
    usage += '   operation: check_value | alert_value | alert_ts\n'
    usage += '\n'
    usage += '   - check_value <counter_name>\n'
    usage += '   - alert_value <counter_name> <warning_threshold> <alert_threshold>\n'
    usage += '     Triggers alert based on the value of the counter\n'
    usage += '\n'
    usage += '   - alert_ts <counter_name> <warning_threshold> <alert_threshold>\n'
    usage += '     Triggers alert based on the age of the counter\n'
    return usage

def parse_argv():
    global db_host, db_user, db_password, db_name
    global operation, counter_name, operation_params, lower_bound

    parser = OptionParser()
    parser.add_option('-n', '--host', dest='db_host',
                      help='FT database with counters table (required)')
    parser.add_option('-u', '--user', dest='db_user',
                      help='FT database user (required)')
    parser.add_option('-p', '--password', dest='db_password',
                      help='FT database password (required)')
    parser.add_option('-d', '--database', dest='db_name',
                      help='FT database name',
                      default='ftdb')
    parser.add_option('-l', '--lower_bound', dest='lower_bound',
                      default=False, action='store_true',
                      help='use lower bounds for operations thresholds')
    try:
        (options, args) = parser.parse_args()
    except:
        print usage()
        return 3

    if len(args) >= 6:
        #this should be deprecated, but remains for compatibility
        db_host, db_user, db_password, db_name, operation, counter_name = args[:6]
        operation_params = args[6:]
    else:
        if not (options.db_host and options.db_user and options.db_password):
            print 'Database host, user and password are required options'
            print usage()
            return 3
        if len(args) < 2:
            print 'Operation and at least one operational parameter required'
            print usage()
            return 3

        db_host = options.db_host
        db_user = options.db_user
        db_password = options.db_password
        db_name = options.db_name
        operation = args[0]
        counter_name = args[1]
        operation_params = args[2:]
    lower_bound = options.lower_bound

    if not ((operation == 'check_value' and len(operation_params) == 0)
            or (operation == 'alert_value' and len(operation_params) == 2)
            or (operation == 'alert_ts' and len(operation_params) == 2)
            or (operation == 'alert_total' and len(operation_params) == 2)):
        print 'Invalid parameters!'
        print usage()
        return 3

    return 0

def threshold(state, value_to_be_checked, warning_threshold, alert_threshold):
    if lower_bound is False:
        if value_to_be_checked > alert_threshold:
            state = 'CRITICAL'
        elif value_to_be_checked > warning_threshold:
            if state is None:
                state = 'WARNING'
    else:
        if value_to_be_checked < alert_threshold:
            state = 'CRITICAL'
        elif value_to_be_checked < warning_threshold:
            if state is None:
                state = 'WARNING'
    return state

def main():
    ret_code = parse_argv()
    if ret_code:
        return ret_code
    state = None
    msgs = list()
    rows = get_values()
    
    if operation == 'check_value':
        for row in rows:
            value, node_name, mtime, mby, hostname, pid = row
            print value, node_name,  mtime, mby, pid
        return 0
    
    sum_value = 0
    op_type_aggrigate = False
    for row in rows:
        value, node_name, mtime, mby, hostname, pid = row
        
        warning_threshold = int(operation_params[0])
        alert_threshold = int(operation_params[1])
        
        if operation == 'alert_value':
            value_to_be_checked = value
            msg = '%s on %s is %s' % (counter_name, node_name,
                    value_to_be_checked)
        elif operation == 'alert_ts':
            value_to_be_checked = int(time.time() - mtime)
            msg = '%s on %s updated %s secs ago' % (counter_name, node_name, 
                    value_to_be_checked)
        elif operation == 'alert_total':
            op_type_aggrigate = True
            sum_value += value
            msg = '%s on %s is %s' % (counter_name, node_name, value)
        else:
            # should never come here
            print 'invalid operaiton: %s' % operation
            return 3
        msgs.append(msg)
        
        if op_type_aggrigate is False:
            state = threshold(state, value_to_be_checked, warning_threshold, alert_threshold)
    if op_type_aggrigate is True:
        state = threshold(state, sum_value, warning_threshold, alert_threshold)
        msg = 'total %s on %s is %s' % (counter_name, node_name, sum_value)
        msgs.insert(0,msg)
    msgs_str = '\n'.join(msgs)
    if state == 'CRITICAL':
        print 'CRITICAL - %s' % (msgs_str,)
        return 2
    if state == 'WARNING':
        print 'WARNING - %s' % (msgs_str,)
        return 1
    print 'OK - %s' % (msgs_str,)
    return 0

if __name__ == '__main__':
    try:
        ret_code = main()
    except:
        import traceback
        traceback.print_exc()
        ret_code = 3

    sys.exit(ret_code)
