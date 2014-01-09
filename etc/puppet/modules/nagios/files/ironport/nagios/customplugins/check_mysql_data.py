#!/usr/bin/python26

# -*- coding: ascii -*-

# Connects to a mysql database and executes a sql statement,
# checking for valid data.
# Mike "Shaun" Lindsey <miklinds@ironport.com> 1/16/2009

import base64
import os
import socket
import sys
import traceback
import time
import MySQLdb
import _mysql_exceptions
import re

from optparse import OptionParser

def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    usage = """usage %prog [options]
If critical or warning thresholds are given, a numeric value is expected from query.
Result is tested against those thresholds, less than threshold is good.
If neither is given, then if query returns any data, it is considered good.
--inverse will reverse those tests."""
    parser = OptionParser(usage)
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="MySQL host to connect to.")
    parser.add_option("-d", "--db", type="string", dest="db",
                            help="Database to connect to.")
    parser.add_option("-u", "--user", type="string", dest="user",
                            help="MySQL user to connect as.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="MySQL password to use.")
    parser.add_option("-q", "--query", type="string", dest="query",
                            help="MySQL query to run.")
    parser.add_option("-c", "--critical", type="float", dest="critical",
                            help="Critical Threshold")
    parser.add_option("-w", "--warning", type="float", dest="warning",
                            help="Warning Threshold")
    parser.add_option("-a", "--accurate", type="string", dest="accurate",
                            help="Accurate Threshold. If result != this walue -- exit with Critical.")
    parser.add_option("-t", "--time", action="store_true", dest="time",
                            default=False,
                            help="Thresholds are in seconds, instead of for output.")
    parser.add_option("-n", "--numeric", action="store_true", dest="numeric",
                            default=False,
                            help="Treat any non-number as a critical error.")
    parser.add_option("-i", "--inverse", action="store_true", dest="inverse",
                            default=False,
                            help="Invert test logic.")
    parser.add_option("-s", "--semicolon", action="store_true", dest="semicolon",
                            default=False,
                            help="Allow semicolon in query string.  Prabably will break.")
    parser.add_option("-r", "--raw", action="store_true", dest="raw",
                            default=False,
                            help="Only output a single value query result (1 row, 1 column) and any mysql errors")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    global options
    (options, args) = parser.parse_args()
    exitflag = 0
    if not options.host:
        exitflag = 1
	print "--host is not optional"
    if not options.db:
        exitflag = 1
	print "--db is not optional"
    if not options.user:
        exitflag = 1
	print "--user is not optional"
    if not options.password:
        exitflag = 1
	print "--password is not optional"
    if not options.query:
        exitflag = 1
	print "--query is not optional"
    elif ';' in options.query and not options.semicolon:
        exitflag = 1
        print "semicolon not supported in --query"
    if ((options.critical is not None and options.warning is not None) and
        (options.critical < options.warning) and not options.inverse):
        print "Critical must be greater than Warning"
	exitflag = 1
    if ((options.critical is not None and options.warning is not None) and
        (options.critical >= options.warning) and options.inverse):
        print "Critical must be less than Warning, if --inverse is passed."
	exitflag = 1
    if options.time and not options.critical and not options.warning:
        print "Must include --critical and/or --warning with --time"
        exitflag = 1
    if ((options.critical is not None) and (int(options.critical) == options.critical)): options.critical = int(options.critical)
    if ((options.warning is not None) and (int(options.warning) == options.warning)): options.warning = int(options.warning)
    if exitflag > 0:
        print
        parser.print_help()
        sys.exit(3)
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " + 
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

    return options

def init_db():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    try:
        conn = MySQLdb.connect (host = options.host,
                            user = options.user,
                            passwd = options.password,
                            db = options.db)
    except:
        print "MySQL connect error"
	sys.exit(exit['unkn'])
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return conn

def do_sql(sql):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    conn = init_db()
    cursor = conn.cursor()
    if options.verbose: print "Executing sql:  %s, %s" % (sql, conn)
    from warnings import filterwarnings
    filterwarnings( 'ignore', category = MySQLdb.Warning )
    cursor.execute(sql)
    val = cursor.fetchall()
    if options.verbose: print "Results: %s" % (val)
    conn.commit()
    conn.close()
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return val


if __name__ == '__main__':
    init()
    exit = {}
    exit['ok'] = 0
    exit['warn'] = 1
    exit['crit'] = 2
    exit['unkn'] = 3

    try:
        start_time = time.time()
        value = do_sql(options.query)
        end_time = time.time()
    except:
        print "Unknown connection or select error."
        sys.exit(exit['unkn'])

    if options.inverse:
        test = 'lte'
    else:
        test = 'gte'
    if options.raw:
        if (len(value) != 1 or len(value[0]) != 1):
            if (len(value) != 1): print "Expected one return value, got %s rows" % (len(value))
            if (len(value) == 1): print "Expected one return value, got %s columns" % (len(value[0]))
            sys.exit(3)
        print "%s" % (value[0])
        sys.exit(0)

    if options.accurate:
#        if (len(value) != 1 or len(value[0]) != 1):
#            if (len(value) != 1): print "Expected one return value, got %s rows" % (len(value))
#            if (len(value) == 1): print "Expected one return value, got %s columns" % (len(value[0]))
#            sys.exit(exit['unkn'])
        if str(value[0][0]) == (options.accurate):
            print "OK - MySQL query returned value '%s' as expected." % (value[0][0])
            sys.exit(exit['ok'])
        else:
            print "CRITICAL - MySQL query returned unexpected data '%s' (expected %s)." % (value[0][0],options.accurate)
            sys.exit(exit['crit'])

    if options.time:
        rows = len(value)
        cols = len(value[0])
        duration = end_time - start_time
        if rows == 0 or cols == 0:
            if (rows == 0):
                print "Expected some return value, got 0 rows"
            elif (cols == 0):
                print "Expected some return value, got 0 columns"
            sys.exit(3)

        # time query, and status is OK
        if (((options.warning is not None and not options.inverse) and
             (duration < options.warning)) or
            ((options.critical is not None and options.warning is None and not options.inverse) and
             (duration < options.critical)) or
            ((options.warning is not None and options.inverse) and
             (duration > options.warning)) or
            ((options.critical is not None and options.warning is None and options.inverse) and
             (duration > options.critical))):
            if (options.warning):
                thresh = options.warning
            else:
                thresh = options.critical
            print "OK got %s rows in %.2fs, Threshold is %ss" % (rows, duration, thresh)
            sys.exit(exit['ok'])

        # Numerical query and status is WARNING
        if (((options.warning is not None and options.critical is not None and not options.inverse) and
             (options.warning <= duration < options.critical)) or
            ((options.warning is not None and options.critical is None and not options.inverse) and
             (options.warning <= duration)) or
            ((options.warning is not None and options.critical is not None and options.inverse) and
             (options.warning >= duration > options.critical)) or
            ((options.warning is not None and options.critical is None and options.inverse) and
             (options.warning >= duration))):
            print "WARNING got %s rows in %.2fs %s %ss." % (rows, duration, test, options.warning),
            if (options.critical is not None): print "Crit at %ss." % (options.critical),
            print
            sys.exit(exit['warn'])

        # Numerical query and status is CRITICAL
        if (((options.critical is not None and not options.inverse) and
             (options.critical <= duration)) or
            ((options.critical is not None and options.inverse) and
             (options.critical >= duration))):
            print "CRITICAL got %s rows in %.2fs %s %ss" % (rows, duration, test, options.critical)
            sys.exit(exit['crit'])

    if (options.critical is not None or options.warning is not None):
        if (len(value) != 1 or len(value[0]) != 1):
            if (len(value) != 1): print "Expected one return value, got %s rows" % (len(value))
            if (len(value) == 1): print "Expected one return value, got %s columns" % (len(value[0]))
            sys.exit(3)
        try:
            value = float(value[0][0])
        except:
            if options.numeric:
                print "Thresholds given, but return from query not a number ('%s')." % (value[0][0])
                sys.exit(exit['crit'])
            else:
                print "Thresholds given, but return from query not a number."
                sys.exit(exit['unkn'])
        else:
            if (value == int(value)): value = int(value)

        # Numerical query, and status is OK
        if (((options.warning is not None and not options.inverse) and
             (value < options.warning)) or
            ((options.critical is not None and options.warning is None and not options.inverse) and
             (value < options.critical)) or
            ((options.warning is not None and options.inverse) and
             (value > options.warning)) or
            ((options.critical is not None and options.warning is None and options.inverse) and
             (value > options.critical))):
            if (options.warning):
                thresh = options.warning
            else:
                thresh = options.critical
            print "OK Value %s, Threshold is %s" % (value, thresh)
            sys.exit(exit['ok'])

        # Numerical query and status is WARNING
        if (((options.warning is not None and options.critical is not None and not options.inverse) and
             (options.warning <= value < options.critical)) or
            ((options.warning is not None and options.critical is None and not options.inverse) and
             (options.warning <= value)) or
            ((options.warning is not None and options.critical is not None and options.inverse) and
             (options.warning >= value > options.critical)) or
            ((options.warning is not None and options.critical is None and options.inverse) and
             (options.warning >= value))):
            print "WARNING Value %s %s %s." % (value, test, options.warning),
            if (options.critical is not None): print "Crit at %s." % (options.critical),
            print
            sys.exit(exit['warn'])

        # Numerical query and status is CRITICAL
        if (((options.critical is not None and not options.inverse) and
             (options.critical <= value)) or
            ((options.critical is not None and options.inverse) and
             (options.critical >= value))):
            print "CRITICAL Value %s %s %s" % (value, test, options.critical)
            sys.exit(exit['crit'])

    # Non numerical query and status is OK
    if ((not options.inverse) and (len(value) != 0)): 
        print "OK - MySQL query returned '%s'" % (value[0][0])
        sys.exit(exit['ok'])
    # Non Numerical Query and status is CRITICAL
    if ((not options.inverse) and (len(value) == 0)): 
        print "CRITICAL - MySQL query returned no data"
        sys.exit(exit['crit'])

    # Inverse Non numerical query and status is OK
    if ((options.inverse) and (len(value) == 0)): 
        print "OK - MySQL query returned no data"
        sys.exit(exit['ok'])
    # Inverse Non numerical query and staus is CRITICAL
    if ((options.inverse) and (len(value) != 0)): 
        print "CRITICAL - MySQL query returned data when none was expected (number of rows returned: %d)" % (len(value))
        sys.exit(exit['crit'])

    # Should never get here!
    print "Something odd just happened.  Value: %s, Length: %s" % (value, len(value))
    if (options.warning is None): print "No Warning threshold"
    if (options.critical is None): print "No Critical threshold"
    if (options.inverse): print "Inverse mode enabled"
    sys.exit(3)
