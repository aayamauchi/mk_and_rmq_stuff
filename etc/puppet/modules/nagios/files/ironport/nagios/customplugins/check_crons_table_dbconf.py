#!/usr/bin/python26

"""
Nagios monitor for crons table entries.

:Status: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_crons_table_dbconf.py#2 $
:Authors: aflury, lrm
"""

import getpass
import optparse
import MySQLdb
import MySQLdb.cursors
import sys
import traceback
import time


USAGE = """
%s -H <host> -u <user> -p <password> -d <db> -c <critical> -w <warning> --cluster <cluster> [-C <command>]

host      - Database host.
user      - Database user.
password  - Database password.
db        - Database name containing the target 'crons' table.
critical  - Number of seconds a job can be running before a critical alert is
            raised.
command   - The command to be monitored.  If not specified, every entry in the
            crons table will be checked.
warning   - Number of seconds a job can be running before a warning is raised.
cluster   - The cluster you want to check for the crons job in.
""" % (sys.argv[0])


def fmt_time(timestamp):
    timestamp = int(timestamp)
    return time.strftime('%b/%d %I:%M %p', time.localtime(timestamp))


def gen_err(row):
    return '%s last ran %s (cluster \'%s\', id=%s) @ %s' % (
            row['host_name'], row['cron_name'], row['cluster_name'],
            row['cron_id'], fmt_time(row['start']))


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
    optparser.add_option('', '--cluster', dest='cluster', default=None,
            action='store', type="string")
    optparser.add_option('-w', '--warning', dest='warning', default=None,
            action='store', type="int")
    optparser.add_option('-C', '--command', dest='command', default=None,
            help='The command to be monitored.  If not specified, every ' +
                 'entry in the crons table will be checked.',
            action='store')
    try:
        (opt, args) = optparser.parse_args()
    except optparse.OptParseError, err:
        print err
        sys.exit(2)

    if not (opt.host and opt.user and opt.password and opt.db and opt.critical
            and opt.warning):
        print USAGE
        sys.exit(2)

    try:
        conn = MySQLdb.connect(user=opt.user, passwd=opt.password, db=opt.db,
                host=opt.host, cursorclass=MySQLdb.cursors.DictCursor)
        cursor = conn.cursor()
    except MySQLdb.Error,e:
        print "CRITICAL: Can not execute query: %s" % (e)
        sys.exit(2)

    now = int(time.time())


    query = """
    SELECT c.cron_id, c.cluster_name, c.cron_name,
           c.frequency, cj.start, cj.host_name,
           c.day_of_month, c.day_of_week, c.hour, c.minute,
           cj.last_success, cj.mon_lock, cj.result
    FROM crons c INNER JOIN cron_jobs cj using (cron_id)
    """

    if opt.command and opt.cluster is None:
        query += "WHERE c.cron_name = '%s'" % (opt.command)

    if opt.command is None and opt.cluster:
        query += "WHERE c.cluster_name = '%s'" % (opt.cluster)

    if opt.command and opt.cluster:
        query += "WHERE c.cron_name = '%s' and c.cluster_name = '%s'" % (
            opt.command, opt.cluster)

    try:
        cursor.execute(query)
        rows = cursor.fetchall()
    except MySQLdb.Error:
        traceback.print_exc()
        sys.exit(2)

    warnings = []
    criticals = []

    if not opt.command == None and len(rows) == 0:
        print 'WARNING - Command %s has no start value. Disabled?' % (opt.command)
        sys.exit(1)

    for row in rows:
        if not row['mon_lock'] == None and not row['result'] == None:
            print 'CRITICAL - Command %s (cluster \'%s\', id=%s) ' \
                  'locked on host %s with exit code of %d.' % ( \
                row['cron_name'], row['cluster_name'], row['cron_id'], \
                row['host_name'], row['result'])
            sys.exit(2)

        if row['start'] == None:
            if not opt.command == None:
                print 'WARNING - Command %s (cluster \'%s\', id=%s) has no start value. Disabled?' % (row['cron_name'], row['cluster_name'], row['cron_id'])
                sys.exit(1)
            continue
    
        localtime = time.localtime(row['start'])

        if row['last_success'] and row['start'] > row['last_success']:
            # The process must be running (or failed) if start is
            # more recent than lastsuccess.
            runlength = now - row['start']
        else:
            # Process has already finished, or has never finished.  Can't
            # determine how long it's been running.
            runlength = None

        if not row.get('day_of_week') == None:
            if runlength and runlength > opt.critical:
                criticals.append(row)
            elif localtime[6] != (row['day_of_week'] - 1) or (
                    runlength and runlength > opt.warning):
                warnings.append(row)
        elif not row.get('hour') == None:
            if runlength and runlength > opt.critical:
                criticals.append(row)
            elif localtime[3] != row['hour'] or (
                    runlength and runlength > opt.warning):
                warnings.append(row)
        elif not row.get('frequency') == None:
            if now - row['start'] > row['frequency'] + opt.critical:
                criticals.append(row)
            elif now - row['start'] > row['frequency'] + opt.warning:
                warnings.append(row)

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
        print "OK - %s (cluster \'%s\', id = %s) last ran @ %s." % ( \
                row['cron_name'], row['cluster_name'], row['cron_id'], \
                fmt_time(row['start']))
