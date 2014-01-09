#!/usr/bin/python26
"""
Nagios monitor for crons table entries.

:Status: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_corpus_crons_table.py#1 $
:Authors: aflury
"""

import getpass
import optparse
import MySQLdb
import MySQLdb.cursors
import sys
import traceback
import time


USAGE = """
%s -H <host> -u <user> -p <password> -d <db> [-c <critical> -w <warning> | -t] [-C <command>]

host      - Database host.
user      - Database user.
password  - Database password.
db        - Database name containing the target 'crons' table.
critical  - Number of seconds a job can be running before a critical alert is
            raised.
warning   - Number of seconds a job can be running before a warning is raised.
-t        - Use thresholds provided in database.
command   - The command to be monitored.  If not specified, every entry in the
            crons table will be checked.
""" % (sys.argv[0])


def fmt_time(timestamp):
    timestamp = int(timestamp)
    return time.strftime('%b/%d %I:%M %p', time.localtime(timestamp))


def gen_err(row):
    return '%s last ran %s @ %s' % (
            row['hostname'], row['command'],
            fmt_time(row['lastrunstart']))


if __name__ == '__main__':
    optparser = optparse.OptionParser(usage=USAGE)
    optparser.add_option('-H', '--host', dest='host', default=None,
            action='store')
    optparser.add_option('-u', '--user', dest='user', default=None,
            action='store')
    optparser.add_option('-p', '--password', dest='password', default=None,
            action='store')
    optparser.add_option('-d', '--db', dest='db', default=None,
            action='store')
    optparser.add_option('-c', '--critical', dest='critical', default=None,
            action='store', type="int")
    optparser.add_option('-w', '--warning', dest='warning', default=None,
            action='store', type="int")
    optparser.add_option('-t', '--thresholds', dest='thresholds', default=False,
            action='store_true')
    optparser.add_option('-C', '--command', dest='command', default=None,
            help='The command to be monitored.  If not specified, every ' +
                 'entry in the crons table will be checked.',
            action='store')
    try:
        (opt, args) = optparser.parse_args()
    except optparse.OptParseError, err:
        print err
        sys.exit(2)

    if not (opt.host and opt.user and opt.password and opt.db and (opt.thresholds or (opt.critical and opt.warning))):
        print USAGE
        sys.exit(2)

    try:
        conn = MySQLdb.connect(user=opt.user, passwd=opt.password, db=opt.db,
                host=opt.host, cursorclass=MySQLdb.cursors.DictCursor)
        cursor = conn.cursor()
    except MySQLdb.Error:
        traceback.print_exc()
        sys.exit(2)

    now = int(time.time())
    query0 = """
    SELECT command, frequency, lastrunstart, hostname, day_of_month,
           day_of_week, hour, minute, lastsuccess, mon_lock, result,
           exectime_warning, exectime_error
    FROM crons_local
    """
    query1 = """
    SELECT command, frequency, lastrunstart, hostname, day_of_month,
           day_of_week, hour, minute, lastsuccess, mon_lock, result
    FROM crons_local
    """
    query2 = """
    SELECT command, frequency, lastrunstart, hostname, lastsuccess, mon_lock, result
    FROM crons_local
    """
    if opt.command:
        query0 += "WHERE command = '%s'" % (opt.command)
        query1 += "WHERE command = '%s'" % (opt.command)
        query2 += "WHERE command = '%s'" % (opt.command)

    if opt.thresholds:
        try:
            cursor.execute(query0)
        except:
            print 'CRITICAL - Unsupported crons table: expected to find thresholds in database'
            sys.exit(2)
    else:
        try:
            cursor.execute(query1)
        except MySQLdb.Error:
            # The crons table must be the older version.
            cursor.execute(query2)

    warnings = []
    criticals = []

    for row in cursor.fetchall():
        if opt.thresholds:
            try:
                opt.critical = int(row['exectime_error'])
                opt.warning  = int(row['exectime_warning'])
            except:
                print "CRITICAL - Invalid thresholds provided in database"
                sys.exit(2)
            #print "Got thresholds from database: warning[%d], critical[%d]" % (opt.warning, opt.critical)

        if not row['mon_lock'] == None and not row['result'] == None:
            print 'CRITICAL - Command %s locked on host %s with exit code of %d.' % (row['command'], row['hostname'], row['result'])
            sys.exit(2)

        if row['result'] != None and row['result'] != 0:
            print 'WARNING - Command %s on host %s has non-zero exit status of %d.' % (row['command'], row['hostname'], row['result'])
            sys.exit(1)

        if row['lastrunstart'] == None: 
            if not opt.command == None:
                print 'WARNING - Command %s has no lastrunstart value. Disabled?' % (row['command'])
                sys.exit(1)
            continue
    
        localtime = time.localtime(row['lastrunstart'])

        if row['lastsuccess'] and row['lastrunstart'] > row['lastsuccess']:
            # The process must be running (or failed) if lastrunstart is
            # more recent than lastsuccess.
            runlength = now - row['lastrunstart']
        else:
            # Process has already finished, or has never finished.  Can't
            # determine how long it's been running.
            runlength = None

        # determine job frequency
        if row.get('day_of_month') != None:
            frequency = 2678400
        elif row.get('day_of_week') != None:
            frequency = 604800
        elif row.get('hour') != None:
            frequency = 86400
        elif row.get('minute') != None:
            frequency = 3600
        else:
            frequency = row['frequency']

        if runlength and runlength > frequency + opt.critical:
            criticals.append(row)
        elif runlength and runlength > frequency + opt.warning:
            warnings.append(row)
        elif row['lastsuccess'] and (now - row['lastsuccess']) > (frequency + opt.critical):
            criticals.append(row)
        elif row['lastsuccess'] and (now - row['lastsuccess']) > (frequency + opt.warning):
            criticals.append(row)

    cursor.close()
    conn.close()

    if criticals:
        print "CRITICAL -", 
        print ', '.join([gen_err(row) for row in criticals])
        sys.exit(2)

    if warnings:
        print "WARNING -", 
        print ', '.join([gen_err(row) for row in warnings])
        sys.exit(1)

    if opt.command == None:
        print "OK"
    else:
        try:
            print "OK - %s last ran @ %s." % (
                row['command'], fmt_time(row['lastrunstart']))
        except NameError:
            print "UNKNOWN -", opt.command, " not found in database."
            sys.exit(3)
