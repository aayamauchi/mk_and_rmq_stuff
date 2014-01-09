#!/usr/bin/python26

import optparse
import MySQLdb
import sys
import traceback
import re
import time

# required for slicing time-based thresholds from nagios macros
import os
import datetime

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

def get_message_count(cursor, type, seconds):
    cursor.execute('SELECT count(m.message_id) FROM messages_%s m WHERE m.message_id > 30000000 and m.add_timestamp > unix_timestamp() - %d and ipas_verdict != "unknown"' % (type, seconds))
    message_count = cursor.fetchone()[0]

    return message_count

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
    optparser.add_option('-s', '--seconds', dest='seconds', type='int',
                         help='Time in seconds to count the # of messages.')
    optparser.add_option('-t', '--type', dest='type', default='spam',
                         help='Type of messages to look for.  There should be a messages_<type> table on the database for this to work.  Defaults to spam.')
    optparser.add_option('-w', '--warning', dest='warning',
                         help='Minimum # of messages that should have been added in <time> seconds before a warning is thrown.')
    optparser.add_option('-c', '--critical', dest='critical',
                         help='Minimum # of messages that should have been added in <time> seconds before a critical is thrown.')

    try:
        (opt, args) = optparser.parse_args()
    except optparse.OptParseError, err:
        print err
        sys.exit(2)

    # check for magic _WARN and _CRIT macros
    dt = datetime.datetime.now()
    weekday = dt.weekday()
    hour = dt.timetuple()[3]
    try:
        opt.critical = int(opt.critical)
    except ValueError:
        try:
            opt.critical = int(opt.critical.split()[(weekday*24)+hour])
        except:
            opt.critical = 'UNDEF'
            
    try:
        opt.warning = int(opt.warning)
    except ValueError:
        try:
            opt.warning = opt.warning.split()[(weekday*24)+hour]
        except:
            opt.warning = 'UNDEF'

    try:
        opt.critical = int(opt.critical)
        opt.warning = int(opt.warning)
    except ValueError:
        print "-c, --critical must be either an integer, or $_SERVICECRIT$; not: %s" % (opt.critical)
        print "-w, --warning must be either an integer, or $_SERVICEWARN$; not: %s" % (opt.warning)
        optparser.print_help()
        sys.exit(1)


    if not (opt.user and opt.password and opt.database and opt.seconds):
        print "Must specify -u, -p, and -s options (user, password and seconds)."
        optparser.print_help()
        sys.exit(2)

    conn = setup_db_conn(user=opt.user, host=opt.host, password=opt.password, database=opt.database)
    cursor = conn.cursor()

    message_count = int(get_message_count(cursor, opt.type, opt.seconds))

    if opt.warning == None and opt.critical == None:
        print "%d %s messages added in the last %d seconds." % (message_count, opt.type, opt.seconds)
        sys.exit(0)

    if message_count < opt.critical:
        print "CRITICAL - %d %s messages added in the last %d seconds. Critical threshold %d." % (message_count, opt.type, opt.seconds, opt.critical)
        sys.exit(2)

    if message_count < opt.warning:
        print "WARNING - %d %s messages added in the last %d seconds. Warning threshold %d." % (message_count, opt.type, opt.seconds, opt.warning)
        sys.exit(1)

    print "OK - %d %s messages added in the last %d seconds.  Warning threshold %d." % (message_count, opt.type, opt.seconds, opt.warning)
