#!/usr/bin/python26
"""Nagios compatible output for checking different aspects of the vector
system. Run with --help for all usage. Aspects and thresholds are documented in
the vector design spec.

:Authors: djones
:Status: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/nagios_vector.py#1 $
"""
# all statistics we're interested in are in vector's stats table in the vector
# DB. simply provide cmdline switches to the different aspects we wish to have
# seperate alerts for.

import MySQLdb
import MySQLdb.cursors
import optparse
import sys
import traceback

DB_STATS_TABLE = 'stats_summary'
DELIMITER = ':'

if __name__ == '__main__':
    usage = """\
%prog [-d db_settings] [-w monitor_what] [-v thresholds] [-p thresholds]

VECTOR APPLICATION NAGIOS MONITORING SCRIPT

-d database_settings: the settings to connect to the vector DB to check the
   stats table. no spaces allowed. format:
     dbhost:dbuser:dbpassword:db

-w monitor_what: the 'who' and 'what' to check. no spaces. format:
     who:what

     special case: what="heartbeat" for who=extractor or any of the plugins.
     this will read your -v thresholds to compare with seconds ago updated.

     special case: who=<table_name> and what="last_insert". This will find the
     most recent mtime in the table given and compare it to the current time.
     If the difference is greater than the threshold the monitor will trigger.
     Use -v options to specify the thesholds.

-v value thresholds: the 'value' column thresholds and whether the DB value
   should be less than (lt) or greater than (gt) your thresholds. specify all
   3 thresholds of warn:error:page with a 0 if not applicable. no spaces
   allowed. format:
     [lt|gt]:warn_thresh:error_thresh:page_thresh

-p pct threshold: the 'pct' (percentage) column thresholds. same format as
   the -v option. no spaces allowed. you must have either a -v or a -p arg
   or both. format:
     [lt|gt]:warn_thresh:error_thresh:page_thresh

-c delimiter character: optional param if want to change the parameter parse
   delimiter from its default (':').

[ EXAMPLE ]
DB: extractor:assert_failures value = 5
SCRIPT: -w extractor:assert_failures -v lt:1:2:10
EXPECT: the DB value should always be less than our thresholds
RESULT: ERROR because 5 is not < 2

[ MORE INFO ]
This script generically looks up stats in the vector stats_summary table and
exits with a code depending on the threshold you give it. The thresholds are
defined in the vector design spec.

Vector's stats_summary (statistics) table has the following example structure:
+-----------+--------------+--------+-------+-------------------------+
| who       | what         |  value |   pct |                    note |
+-----------+--------------+--------+-------+-------------------------+
| uridb     | helo_matches | 567.00 | 13.44 | IPs with matching HELOs |
| extractor | packets_good |  44.00 | 87.65 | good sbnp packets       |
| extractor |  uptime_days |  22.34 |  0.00 | days of uptime          |
+-----------+--------------+--------+-------+-------------------------+
where each 'who' is a component of the system that's reporting a stat, 'what'
is the specific stat type being reported, 'value' is the actual stat value,
and 'pct' is a percentage related to the value (if applicable).

These are 'rollup' or summary statistics for all processes."""

    opt_parser = optparse.OptionParser(usage=usage)
    opt_parser.add_option('-d', '--db', type='string', dest='db',
        help='DB connection variables: dbhost:user:password:db')
    opt_parser.add_option('-w', '--what', type='string', dest='what',
        help='what to monitor: who:what')
    opt_parser.add_option('-v', '--value', type='string', dest='val',
        help='value thresholds: [lt|gt]:warn:error:page, 0 for n/a')
    opt_parser.add_option('-p', '--pct', type='string', dest='pct',
        help='percent thresholds: [lt|gt]:warn:error:page, 0 for n/a')
    opt_parser.add_option('-c', '--delim', type='string', dest='delim_',
        help='parameter delimiter character to use instead of "%s"' % DELIMITER)

    try:
        (opt, args) = opt_parser.parse_args()
    except optparse.OptParseError:
        print "SCRIPT_ERROR: invalid commandline arguments."
        opt_parser.print_help()
        traceback.print_exc()
        sys.exit(2)

    # check required args
    msg = []
    if opt.db == None:
        msg.append('-d database args is required!')
    if opt.what == None:
        msg.append('-w you must specify what to monitor!')
    if opt.val == None and opt.pct == None:
        msg.append('-v,-p either value or pct is required!')
    if msg:
        print "SCRIPT_ERROR: required args missing:\n%s\n" % '\n'.join(msg)
        opt_parser.print_help()
        sys.exit(2)

    # check for delimiter change
    if opt.delim_:
        delim = opt.delim_
    else:
        delim = DELIMITER

    # parse out required args
    try:
        (host, user, passwd, db) = opt.db.split(delim)
        (who, what) = opt.what.split(delim)
        if opt.val:
            (v, v_warn, v_error, v_page) = opt.val.split(delim)
            v_lt = (v.lower() == 'lt') and 1 or 0
        if opt.pct:
            (p, p_warn, p_error, p_page) = opt.pct.split(delim)
            p_lt = (p.lower() == 'lt') and 1 or 0
    except:
        msg = traceback.format_exc().split('\n')[-2]
        print 'SCRIPT_ERROR: problems parsing args: %s' % msg
        sys.exit(2)

    # get mysql connection
    try:
        conn = MySQLdb.connect(host=host, user=user, passwd=passwd, db=db)
        cursor = conn.cursor(MySQLdb.cursors.DictCursor)
    except MySQLdb.Error, e:
        print "SCRIPT_ERROR: DB connection error: %s" % (e,)
        sys.exit(2)

    # query db for desired stat
    msg = ''
    try:
        if what.lower() == 'last_insert':
            sql = """select '%s' as who,
                'last_insert',
                UNIX_TIMESTAMP() - UNIX_TIMESTAMP(MAX(mtime)) as value,
                0.0 as pct,
                'seconds since last insert' as note,
                mtime
                from %s
                """ % (who, who)
        elif what.lower() == 'heartbeat':
            w = (who.lower() == 'extractor') and 'uptime_days_' or 'worktime'
            sql = """select who,
                'heartbeat',
                avg(unix_timestamp()-unix_timestamp(mtime)) as value,
                0.0 as pct,
                'heartbeat in seconds' as note,
                max(mtime) as mtime
                from stats
                where who='%s' and what='%s'""" % (who, w)
        elif what.lower() == 'restarts':
            sql = "select who,'restart',value-pct as value,0.0,"\
                  "'days between avg and min extractor uptime' as note,mtime"\
                  " from %s where who='extractor' and what='uptime_days_'" % \
                  (DB_STATS_TABLE,)
        else:
            sql = "select who,what,value,pct,note,mtime from %s where"\
                  " who='%s' and what='%s'" % (DB_STATS_TABLE, who, what)
        cursor.execute(sql)
        conn.commit()
        rows = cursor.fetchall()
        if not len(rows):
            msg = '%s:%s is not a valid who:what' % (who, what)
            raise
    except:
        if not msg:
            msg = traceback.format_exc().split('\n')[-2]
        print 'SCRIPT_ERROR: problems querying the DB: %s' % msg
        sys.exit(3)

    # apply thresholds to all host rows that come back
    # apply in reverse severity order to end with the worst

    ifok = ''
    # ---[ test value ]---
    sev = ''
    try:
        if opt.val:
            for row in rows:
                thr = 0.0
                sign = type = sev = ''
                if row['value']:
                    val = float(row['value'])
                else:
                    val = 0.0
                ifok = val

                v_warn = float(v_warn)
                if v_warn > 0 and v_lt and val > v_warn:
                    sign = '>'
                    (type, sev, thr) = ('warn', 'WARNING', v_warn)
                if v_warn > 0 and not v_lt and val < v_warn:
                    sign = '<'
                    (type, sev, thr) = ('warn', 'WARNING', v_warn)

                v_error = float(v_error)
                if v_error > 0 and v_lt and val > v_error:
                    sign = '>'
                    (type, sev, thr) = ('error', 'ERROR', v_error)
                if v_error > 0 and not v_lt and val < v_error:
                    sign = '<'
                    (type, sev, thr) = ('error', 'ERROR', v_error)

                v_page = float(v_page)
                if v_page > 0 and v_lt and val > v_page:
                    sign = '>'
                    (type, sev, thr) = ('page', 'CRITICAL', v_page)
                if v_page > 0 and not v_lt and val < v_page:
                    sign = '<'
                    (type, sev, thr) = ('page', 'CRITICAL', v_page)

                if sev:
                    print '%s: db.%s.%s.value[%.1f] %s %s_threshold'\
                          '[%.1f] (%s)' % (sev, who, what,
                          val, sign, type, thr, row['note'])

    except:
        msg = traceback.format_exc().split('\n')[-2]
        print 'SCRIPT_ERROR: problems testing value thresholds: %s' % msg
        sys.exit(2)

    # ---[ test pct ]---
    try:
        if opt.pct:
            for row in rows:
                thr = 0.0
                sign = type = sev = ''
                if row['pct']:
                    pct = float(row['pct'])
                else:
                    pct = 0.0
                ifok = pct

                p_warn = float(p_warn)
                if p_warn > 0 and p_lt and pct > p_warn:
                        sign = '>'
                        (type, sev, thr) = ('warn', 'WARNING', p_warn)
                if p_warn > 0 and not p_lt and pct < p_warn:
                        sign = '<'
                        (type, sev, thr) = ('warn', 'WARNING', p_warn)

                p_error = float(p_error)
                if p_error > 0 and p_lt and pct > p_error:
                        sign = '>'
                        (type, sev, thr) = ('error', 'ERROR', p_error)
                if p_error > 0 and not p_lt and pct < p_error:
                        sign = '<'
                        (type, sev, thr) = ('error', 'ERROR', p_error)

                p_page = float(p_page)
                if p_page > 0 and p_lt and pct > p_page:
                        sign = '>'
                        (type, sev, thr) = ('page', 'CRITICAL', p_page)
                if p_page > 0 and not p_lt and pct < p_page:
                        sign = '<'
                        (type, sev, thr) = ('page', 'CRITICAL', p_page)

                if sev:
                    print '%s: db.%s.%s.pct[%.1f] %s %s_threshold'\
                          '[%.1f] (%s)' % (sev, who, what,
                          pct, sign, type, thr, row['note'])

    except:
        msg = traceback.format_exc().split('\n')[-2]
        print 'SCRIPT_ERROR: problems testing pct thresholds: %s' % msg
        sys.exit(2)

    if sev:
        (type == 'warn') and sys.exit(1) or sys.exit(2)
    else:
        print "OK: %s:%s=%s is within thresholds" % (who, what, ifok)
