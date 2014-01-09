#!/bin/env python26

import getpass
import optparse
import MySQLdb
import MySQLdb.cursors
import sys
import traceback
import time


USAGE = """
%s -H <host> -u <user> -p <password> -d <db> -c <critical> -w <warning> -C <command> -L local_host -v <verbosity>

host       - Database host.
user       - Database user.
password   - Database password.
db         - Database name containing the target 'crons' table.
critical   - Number of seconds a job can be running before a critical alert is
             raised.
warning    - Number of seconds a job can be running before a warning is raised.
command    - The command to be monitored.  If not specified, every entry in the
             crons_local table will be checked.
local_host - Local crons host name
verbosity  - Enable verbose output. Default off.
""" % (sys.argv[0])

query_local0 = """
    SELECT command, frequency, lastrunstart, hostname, day_of_month,
           day_of_week, hour, minute, lastsuccess, mon_lock, result
    FROM crons_local
"""

EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

def fmt_time(timestamp):
    timestamp = int(timestamp)
    return time.strftime('%b/%d %I:%M %p', time.localtime(timestamp))


def gen_err(row):
    if 'msg' in row:
        return '%s last ran %s @ %s (%s)' % (
                row['hostname'], row['command'],
                fmt_time(row['lastrunstart']), row['msg'])
    else:
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
    optparser.add_option('-L', '--local_host', dest='local_host', default=None,
            action='store')
    optparser.add_option('-C', '--command', dest='command', default=None,
            help='The command to be monitored.  If not specified, every ' +
                 'entry in the crons table will be checked.',
            action='store')
    optparser.add_option("-v", "--verbose", action="store_true", dest="verbose",
            default=False, help="Verbose output")

    try:
        (opt, args) = optparser.parse_args()
    except optparse.OptParseError, err:
        print err
        sys.exit(EXIT_UNK)

    if not (opt.host and opt.user and opt.password and opt.db and opt.critical and opt.warning and opt.command \
             and opt.local_host ):
        print USAGE
        sys.exit(EXIT_UNK)

    if opt.warning > opt.critical:
        print "Warning threshold MUST be <= critical"
        sys.exit(EXIT_UNK)

    #Trying to connect to DB
    try:
        conn = MySQLdb.connect(user=opt.user, passwd=opt.password, db=opt.db,
                host=opt.host, cursorclass=MySQLdb.cursors.DictCursor)
        cursor = conn.cursor()
    except MySQLdb.Error:
        traceback.print_exc()
        sys.exit(EXIT_CRIT)

    now = int(time.time())

    query_local0 += "WHERE command = '%s' and hostname = '%s'" % (opt.command, opt.local_host)

    # Trying to get records from crons_local DB

    try:
        cursor.execute(query_local0)
    except:
        print "UNKNOWN. Cannot execute query"
        sys.exit(EXIT_UNK)

    rows = cursor.fetchall()
    if len(rows) > 1:
        print "CRITICAL. Query returned %s results but One expected" % len(rows)
        sys.exit(EXIT_CRIT)

    if len(rows) < 1:
        print "UNKNOWN. Command %s for host %s not found " % (opt.command, opt.local_host)
        sys.exit(EXIT_UNK)

    row = rows[0]
    criticals = []
    warnings = []

    #Parsing result
    if not row['mon_lock'] == None and not row['result'] == None:
        print 'CRITICAL - Command %s locked on host %s with exit code of %d.' % (row['command'], row['hostname'], row['result'])
        if opt.verbose:
            print "MONLOCK DEBUG START".center(80, '-')
            for i in sorted(row.keys()):
                print "%-15s :: %-10s " % (i, row[i])
            print "MONLOCK DEBUG END".center(80, '-')
        sys.exit(EXIT_CRIT)

    if row['result'] != None and row['result'] != 0:
        print 'WARNING - Command %s on host %s has non-zero exit status of %d.' % (row['command'], row['hostname'], row['result'])
        if opt.verbose:
            print "NON-ZERO DEBUG START".center(80, '-')
            for i in sorted(row.keys()):
                print "%-15s :: %-10s " % (i, row[i])
            print "NON_ZERO DEBUG END".center(80, '-')
        sys.exit(EXIT_WARN)

    if row['lastrunstart'] == None:
        print 'WARNING - Command %s has no lastrunstart value. Disabled?' % (row['command'])
        if opt.verbose:
            print "DISABLED? DEBUG START".center(80, '-')
            for i in sorted(row.keys()):
                print "%-15s :: %-10s " % (i, row[i])
            print "DISABLED? DEBUG END".center(80, '-')
        sys.exit(EXIT_WARN)

    localtime = time.localtime(row['lastrunstart'])

    if row['lastsuccess'] and row['lastrunstart'] > row['lastsuccess']:
        # The process must be running (or failed) if lastrunstart is
        # more recent than lastsuccess.
        runlength = now - row['lastrunstart']
        if opt.verbose:
            print "RUNLENGTH DEBUG START".center(80, '-')
            print "RUNLENGTH = %d " % runlength
            print "RUNLENGTH DEBUG END".center(80, '-')
    else:
        # Process has already finished, or has never finished.  Can't
        # determine how long it's been running.
        runlength = None
        if opt.verbose:
            print "RUNELENGTH variable assigned None value"

    #print "Options critical %s " %opt.critical

    # determine job frequency
    if opt.verbose:
        print "DEBUG FREQUENCY START".center(80,'-')
        print "Determining Job's Frequency"
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

    if opt.verbose:
        print "Frequency %s " % frequency
        print "DEBUG FREQUENCY END".center(80,'-')

    if runlength and runlength > frequency + opt.critical:
        row['msg'] = 'runtime exceeds threshold'
        criticals.append(row)
        if opt.verbose:
            print "DEBUG RUNLENGTH START".center(80,'-')
            print "Job's duration exceeds critical threshold"
            print "Runlengt :: %d " % runlength
            print "DEBUG RUNLENGTH END".center(80,'-')
    elif runlength and runlength > frequency + opt.warning:
        row['msg'] = 'runtime exceeds threshold'
        warnings.append(row)
        if opt.verbose:
            print "DEBUG RUNLENGTH START".center(80,'-')
            print "Job's duration exceeds warning threshold"
            print "Runlength :: %d " % runlength
            print "DEBUG RUNLENGTH END".center(80,'-')
    elif row['lastsuccess'] and row['lastrunstart'] < row['lastsuccess'] and (now - row['lastsuccess']) > (frequency + opt.critical):
        row['msg'] = 'last success was %s' % (fmt_time(row['lastsuccess']))
        criticals.append(row)
        if opt.verbose:
            print "DEBUG CRITICAL THRESHOLD START".center(80,'-')
            print "Difference between NOW and lastsuccess exceeds Critical threshold "
            print "Frequency %s " % frequency
            print "Freuqncy + opt.critical = %s " % (frequency + opt.critical)
            print "Difference %s " % (now - row['lastsuccess'])
            print "DEBUG CRITICAL THRESHOLDS END".center(80,'-')
    elif row['lastsuccess'] and row['lastrunstart'] < row['lastsuccess'] and (now - row['lastsuccess']) > (frequency + opt.warning):
        row['msg'] = 'last success was %s' % (fmt_time(row['lastsuccess']))
        warnings.append(row)
        if opt.verbose:
            print "DEBUG WARNING THRESHOLD START".center(80,'-')
            print "Difference between NOW and lastsuccess exceeds Warning threshold "
            print "Frequency %s " % frequency
            print "Freuqncy + opt.critical = %s " % (frequency + opt.warning)
            print "Difference %s " % (now - row['lastsuccess'])
            print "DEBUG WARNING THRESHOLD START".center(80,'-')


    cursor.close()
    conn.close()

    if criticals:
        print "CRITICAL -",
        print ', '.join([gen_err(row) for row in criticals])
        sys.exit(EXIT_CRIT)

    if warnings:
        print "WARNING -",
        print ', '.join([gen_err(row) for row in warnings])
        sys.exit(EXIT_WARN)

    print "OK - %s last ran @ %s." % ( row['command'], fmt_time(row['lastrunstart']))
    if opt.verbose:
        print "DEBUG OK THRESHOLD START".center(80, '-')
        for i in sorted(row.keys()):
            print "%-15s :: %-15s" % (i, row[i])
        print "DEBUG OK THRESHOLD END".center(80, '-')
    sys.exit(EXIT_OK)
