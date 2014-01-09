#!/usr/bin/env python26

import MySQLdb
import sys
import optparse

def setup_options():
    """Used to setup the options for the option parser.  Returns the """ \
            """populated option_parser."""
    usage = "usage: %prog [options] host"
    # Setup options
    option_parser = optparse.OptionParser(usage=usage)
    option_parser.add_option('-H', '--host', type='string', dest='dbhost', help="The database host.")
    option_parser.add_option('-u', '--user', type='string', dest='dbuser', default='nagios', help="The database user. Default: %default")
    option_parser.add_option('-p', '--password', type='string', dest='dbpass', help="The database password.")
    option_parser.add_option('-l', '--location', type='string', dest='location', help="The database host location.")
    option_parser.add_option('-c', '--critical', type='float', dest='critical', help="Critical threshold in hours (integer).")
    option_parser.add_option('-g', action='store_true', dest='graph', default=False, help="Output in cacti friendly format rather than for nagios. Default: %default")
    return option_parser

def parse_options(option_parser):
    # Parse the arguments
    try:
        (options, args) = option_parser.parse_args()
    except optparse.OptParseError:
        print "CRITICAL - Invalid commandline arguments"
        option_parser.print_help()
        traceback.print_exc()
        sys.exit(2)

    if (not options.dbhost) or (not options.dbpass) or (not options.location) or (not options.critical):
        print "CRITICAL - Invalid commandline arguments"
        sys.exit(2)

    return (options, args)

def mysqlexe(sql):
    drows = []
    cnt = cursor.execute(sql)
    cols = [c[0] for c in cursor.description] # Column metadata.
    rows = cursor.fetchall()
    for row in rows:
        drows.append(dict(zip(cols, row)))
    return cnt, drows

if __name__ == '__main__':
    option_parser = setup_options()
    (options, args) = parse_options(option_parser)

    dbcreds = {
        'host': options.dbhost,
        'user': options.dbuser,
        'passwd': options.dbpass,
        'db': 'controller',
        }

    conn = MySQLdb.connect(**dbcreds)
    cursor = conn.cursor()

    # Get all job data.
    genids = {} # {genid: mago} seconds ago the mtime was
    rules = {} # {ruleid: [genid, genid, ...]}
    sql = """
        SELECT *, unix_timestamp() - mtime mago
        FROM job_control
        WHERE gen_id is not NULL
        ORDER BY gen_id asc
    """
    cnt, drows = mysqlexe(sql)
    for drow in drows:
        rid, gid = drow['rule_id'], drow['gen_id']
        genids[gid] = drow['mago']
        if rid not in rules:
            rules[rid] = []
        rules[rid].append(gid)

    # DBWriter status.
    status = {'-1': 0} # {ruleid: mago} oldest undone job per rule
    undone_jobs = 0
    sql = """
        SELECT rule_id, min(gen_id) gid
        FROM dbwriters_status
        WHERE failure_count = 0 AND db_host LIKE '%.XXXX.%'
        GROUP BY rule_id
    """.replace('XXXX', options.location)
    cnt, drows = mysqlexe(sql)
    for drow in drows:
        rid = drow['rule_id']
        status[rid] = 0
        undone = [x for x in rules[rid] if x > drow['gid']]
        if undone:
            undone_jobs += len(undone)
            status[rid] = genids[min(undone)]

    latency_raw = max(status.values())/1.0
    latency_seconds = int(latency_raw + 0.5)
    latency_hours = latency_raw/60.0/60.0
    if not options.graph:
        info = '%.1f hours latency with %d undone jobs' % (latency_hours, undone_jobs)
        if latency_hours > float(options.critical):
            print "CRITICAL - %s" % (info)
            sys.exit(2)
        else:
            print "OK - %s" % (info)
            sys.exit(0)
    else:
        print "latency:%d undonejobs:%d" % (latency_seconds, undone_jobs)
