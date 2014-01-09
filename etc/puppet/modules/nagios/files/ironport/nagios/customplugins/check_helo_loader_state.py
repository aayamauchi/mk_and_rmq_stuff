#!/usr/bin/python26

import optparse
import MySQLdb
import sys
import traceback
import re
import time

def setup_db_conn(user, password, host, database=None):
    try:
        if database is None:
            conn = MySQLdb.connect(user=user, passwd=password, host=host)
        else:
            conn = MySQLdb.connect(user=user, passwd=password, host=host, db=database)
        cursor = conn.cursor()
    except MySQLdb.Error:
        traceback.print_exc(file=sys.stdout)
        sys.exit(2)

    return conn

def get_last_ts(cursor, instance_id):
    cursor.execute('SELECT host,UNIX_TIMESTAMP(NOW())-last_ts AS seconds FROM helo_loader_state WHERE instance_id=%d;' % (instance_id))
    cronsrow = cursor.fetchone()

    return cronsrow

def get_heartbeat(cursor, instance_id):
    cursor.execute('SELECT host,UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(heartbeat) FROM helo_loader_state WHERE instance_id=%d;' % (instance_id))
    cronsrow = cursor.fetchone()

    return cronsrow

if __name__ == '__main__':
    optparser = optparse.OptionParser()
    optparser.add_option('-H', '--host', dest='host', default='localhost',
                         help='Host to monitor.')
    optparser.add_option('-u', '--user', dest='user',
                         help='User to connect with.')
    optparser.add_option('-p', '--password', dest='password',
                         help='Password to connect with.')
    optparser.add_option('-d', '--database', dest='database',
                         help="Database to check.")
    optparser.add_option('-t', '--type', dest='type', default='last_ts',
                         help='Use either heartbeat or last_ts here. Defaults to last_ts')
    optparser.add_option('-w', '--warning', dest='warning', type='int',
                         help='Time to warn at, in seconds, for the delta between now in unixtime and the last checkpoint for a given type.')
    optparser.add_option('-c', '--critical', dest='critical', type='int',
                         help='Time to go crit at, in seconds, for the delta between now in unixtime and the last checkpoint for a given type.')
    optparser.add_option('-i', '--instance_id', type='int',
                         help='Instance id to test' )


    try:
        (opt, args) = optparser.parse_args()
    except optparse.OptParseError, err:
        print err
        sys.exit(2)

    if not (opt.user and opt.password and opt.database and opt.instance_id):
        print "Must specify -u, -p, -i, and -t options (user, password, and instance_id)."
        optparser.print_help()
        sys.exit(2)

    if not ( opt.type == 'last_ts' or opt.type == 'heartbeat'):
        print "type must be either last_ts or heartbeat."
        optparser.print_help()
        sys.exit(2)

    conn = setup_db_conn(user=opt.user, host=opt.host, password=opt.password, database=opt.database)
    cursor = conn.cursor()

    if opt.type == 'last_ts':
        cronsrow = get_last_ts(cursor, opt.instance_id)
        seconds_behind = int(cronsrow[1])
        instance_host = cronsrow[0]

    if opt.type == 'heartbeat':
        cronsrow = get_heartbeat(cursor, opt.instance_id)
        seconds_behind = int(cronsrow[1])
        instance_host = cronsrow[0]


    if opt.warning == None and opt.critical == None:
        print "Instance %d running on %s using type %s last updated %d seconds ago." % (opt.instance_id, instance_host, opt.type, seconds_behind)
        sys.exit(0)

    if seconds_behind > opt.critical:
        print "CRITICAL - Instance %d running on %s as type %s last updated %d seconds ago. Critical threshold %d." % (opt.instance_id, instance_host, opt.type, seconds_behind, opt.critical)
        sys.exit(2)

    if seconds_behind > opt.warning:
        print "WARNING - Instance %d running on %s as type %s last updated %d seconds ago. Warning threshold %d." % (opt.instance_id, instance_host, opt.type, seconds_behind, opt.warning)
        sys.exit(1)

    print "OK - Instance %d running on %s as type %s last updated %d seconds ago. Warning threshold %d." % (opt.instance_id, instance_host, opt.type, seconds_behind, opt.warning)
