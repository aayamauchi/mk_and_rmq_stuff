#!/usr/bin/python26
"""
    retrieve values from ft_counts table.
    This is created as a separate script to minize the 
    dependence on common packages so it can be
    easily used by SysOps
"""

import sys
import time

import MySQLdb

db_host = ''
db_user = ''
db_password = '' 
db_name = ''
operation = ''
counter_name = ''
operation_params = []

def connect_db():
    return MySQLdb.connect(host=db_host, user=db_user, passwd=db_password, db=db_name)

def get_value():
    conn = connect_db()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute("""SELECT value, mtime, mby, hostname, pid
                    FROM ft_counts
                    WHERE counter_name = %s""", counter_name)
    
            rows = cursor.fetchall()
            if rows:
                return rows[0]
            else:
                raise Exception, '%s does not exist' % counter_name
        finally:
            cursor.close()
    finally:
        conn.close()

def print_usage():
    print 'Usage: check_ft_counts <db_host> <db_user> <db_password> <db_name> operation <operation_parameters>'
    print '   operation: check_value | alert_value | alert_ts '
    print ''
    print '   - check_value <counter_name>'
    print '   - alert_value <counter_name> <warning_threshold> <alert_threshold>'
    print '     Triggers alert based on the value of the counter'
    print ''
    print '   - alert_ts <counter_name> <warning_threshold> <alert_threshold>'
    print '     Triggers alert based on the age of the counter'

def parse_argv(argv):
    global db_host, db_user, db_password, db_name 
    global operation, counter_name, operation_params
    if len(argv) < 7:
        print 'It needs at least 7 parameters'
        print_usage()
        return 2

    db_host, db_user, db_password, db_name, operation, counter_name = argv[1:7]
    operation_params = argv[7:]

    if not ((operation == 'check_value' and len(operation_params) == 0)
            or (operation == 'alert_value' and len(operation_params) == 2)
            or (operation == 'alert_ts' and len(operation_params) == 2)):
        print 'Invalid parametersi!'
        print_usage()
        return 2

    return 0
    
def main(argv):
    ret_code = parse_argv(argv)
    if ret_code:
        return ret_code

    value, mtime, mby, hostname, pid = get_value()
    if operation == 'check_value':
        print value, mtime, mby, hostname, pid
        return 0
    else:
        warning_threshold = int(operation_params[0])
        alert_threshold = int(operation_params[1])
        if operation == 'alert_value':
            value_to_be_checked = value
        elif  operation == 'alert_ts':
            value_to_be_checked = int(time.time() - mtime)
        else:
            # should never come here
            print 'invalid operaiton: %s' % operation
            return 2

        #print value_to_be_checked, alert_threshold, warning_threshold

        if value_to_be_checked > alert_threshold:
            print 'CRITICAL - value: ', value_to_be_checked,
            print 'threshold: ', alert_threshold,
	    print 'host: ', hostname
            return 2
        elif value_to_be_checked > warning_threshold:
            print 'WARNING - value: ', value_to_be_checked,
            print 'threshold: ', warning_threshold,
	    print 'host: ', hostname
            return 1
        else:
            print 'OK - value: ', value_to_be_checked,
            print 'threshold: ', alert_threshold,
	    print 'host: ', hostname
            return 0
        

if __name__ == '__main__':
    try:
        ret_code = main(sys.argv)
    except:
        import traceback
        traceback.print_exc()
        ret_code = 2
    sys.exit(ret_code)
