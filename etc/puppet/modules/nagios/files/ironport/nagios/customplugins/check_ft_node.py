#!/usr/bin/python26
"""
    Check the FT Node status

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
app_name = ''
node_name = ''
operation_params = []

def connect_db():
    return MySQLdb.connect(host=db_host, user=db_user, passwd=db_password, db=db_name)

def get_value():
    conn = connect_db()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute("""SELECT app_name, cluster_name, node_name, node_state,
                    last_start_ts, last_hb_ts, hostname, pid, rpcd_host, rpcd_port,
                    httpd_host, httpd_port
                    FROM ft_node_status
                    WHERE app_name = %s
                    AND node_name = %s""", (app_name, node_name))
    
            rows = cursor.fetchall()
            if rows:
                return rows[0]
            else:
                raise Exception, '%s.%s does not exist' % (app_name, node_name)
        finally:
            cursor.close()
    finally:
        conn.close()

def print_usage():
    print 'Usage: check_ft_node.py <db_host> <db_user> <db_password> <db_name> operation <operation_parameters>'
    print '   operation: check | alert '
    print ''
    print '   - check <app_name> <node_name>'
    print '     return the status of given node'
    print ''
    print '   - alert <app_name> <node_name> <warning_threshold> <alert_threshold>'
    print '     check the age of node headbeat against thresholds and return 0, 1 or 2'

def parse_argv(argv):
    global db_host, db_user, db_password, db_name 
    global operation, app_name, node_name, operation_params
    if len(argv) < 8:
        print 'It needs at least 8 parameters'
        print_usage()
        return 3

    db_host, db_user, db_password, db_name, operation, app_name, node_name  = argv[1:8]
    operation_params = argv[8:]

    if not ((operation == 'check' and len(operation_params) == 0)
            or (operation == 'alert' and len(operation_params) == 2)):
        print 'Invalid parametersi!'
        print_usage()
        return 3

    return 0
    
def main(argv):
    ret_code = parse_argv(argv)
    if ret_code:
        return ret_code

    global app_name, node_name

    (app_name, cluster_name, node_name, node_state,
     last_start_ts, last_hb_ts, hostname, pid, rpcd_host, rpcd_port,
     httpd_host, httpd_port) = get_value()
    print app_name, node_name
    if operation == 'check':
        print 'OK - ', app_name, cluster_name, node_name, node_state, \
            last_start_ts, last_hb_ts, hostname, pid, rpcd_host, rpcd_port, \
            httpd_host, httpd_port, "is running"
        return 0
    else:
        warning_threshold = int(operation_params[0])
        alert_threshold = int(operation_params[1])
        if operation == 'alert':
            value_to_be_checked = int(time.time() - last_hb_ts)
        else:
            # should never come here
            print 'invalid operaiton: %s' % operation
            return 3

        if value_to_be_checked > alert_threshold:
            print 'CRITICAL - %s heartbeat on %s has not updated in %d secs' % (
                        app_name, node_name, value_to_be_checked)
            return 2
        elif value_to_be_checked > warning_threshold:
            print 'WARNING - %s heartbeat on %s has not updated in %d secs' % (
                        app_name, node_name, value_to_be_checked)
            return 1
        else:
            print 'OK - %s heartbeat on %s updated %d secs ago' % (
                        app_name, node_name, value_to_be_checked)
            return 0
        

if __name__ == '__main__':
    try:
        ret_code = main(sys.argv)
    except Exception, err:
        print err
        import traceback
        traceback.print_exc()
        ret_code = 3

    sys.exit(ret_code)
