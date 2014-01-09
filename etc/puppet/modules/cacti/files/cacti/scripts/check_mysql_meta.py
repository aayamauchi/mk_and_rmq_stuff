#!/usr/bin/python26

# -*- coding: ascii -*-

# Connects to a mysql database and uses a few tricks to get a quick, accurate rowcount on any system.
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
    x = open('/tmp/mmmmout','a')
    for arg in sys.argv:
        x.write("%s " % (arg))
    x.write("\n")
    usage = """usage %prog [options]"""
    parser = OptionParser(usage)
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="MySQL host to connect to.")
    parser.add_option("-u", "--user", type="string", dest="user",
                            default="cactiuser",
                            help="MySQL user to connect as.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            default="cact1pa55",
                            help="MySQL password to use.")
    parser.add_option("-d", "--db", type="string", dest="db", default="mysql",
                            help="Database to connect to.")
    parser.add_option("-t", "--table", type="string", dest="table",
                            help="MySQL db and table to query for rowcount. (db.table)")
    parser.add_option("--list", type="string", dest="list",
                            help="List.  [dbs|tables|null]")
    parser.add_option("--tablesize", action="store_true", dest="tablesize",
                            default=False,
                            help="Output table size data instead of rowcount.")
    parser.add_option("--field", type="string", dest="field",
                            help="Field to print, [index|data]")
    parser.add_option("--threshold", type="int", dest="threshold",
                            default=1000000,
                            help="Threshold over which we start estimating rowcounts.  Default: 1m")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    global options
    (options, args) = parser.parse_args()
    exitflag = 0
    if not options.host:
        exitflag = 1
	print "--host is not optional"
    if (not options.db):
        options.db = 'mysql'
    if (not options.table and not options.list):
        exitflag = 1
        print "--table is not optional"
    if options.field:
        if options.field != 'data' and options.field != 'index':
            print "--field must be 'data' or 'index'"
            exitflag = 1
    if exitflag > 0:
        print
        parser.print_help()
        sys.exit(3)
    if str(options.table).count('.'):
        (options.db, options.table) = str(options.table).split('.')
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
	sys.exit(3)
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return conn

def do_sql(sql):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    conn = init_db()
    cursor = conn.cursor()
    if options.verbose: print "%s, %s" % (sql, conn)

    cursor.execute(sql)
    val = cursor.fetchall()
    if options.verbose: print "Results: %s" % (val)
    conn.commit()
    conn.close()
    return val

def get_tablesize():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    try:
        length = do_sql("SELECT data_length, index_length FROM information_schema.tables WHERE table_schema='%s' AND table_name='%s'" % (options.db, options.table))
    except:
        if options.verbose: print "Cannot get data from information_schema."
        try:
            status = do_sql("SHOW TABLE STATUS LIKE '%s'" % (options.table))
        except:
            if options.verbose: print "Cannot get data from table status"
            if options.field:
                print "NaN"
            else:
                print "data:NaN index:NaN"
        else:
            if options.field:
                if options.field == 'data':
                    print status[0][6]
                else:
                    print status[0][8]
            else:
                print "data:%s index:%s" % (status[0][6], status[0][8])
    else:
        if options.field:
            if options.field == 'data':
                print length[0][0]
            else:
                print length[0][1]
        else:
            print "data:%s index:%s" % (length[0][0], length[0][1])
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

def get_rowcount():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    try:
        rowdata = do_sql("EXPLAIN SELECT count(*) FROM %s.%s FORCE INDEX (PRIMARY)" % (options.db, options.table))
    except:
        if options.verbose: print "Cannot get rowcount from EXPLAIN."
        try:
            rowdata = do_sql("SELECT count(*) FROM %s.%s FORCE INDEX (PRIMARY)" % (options.db, options.table))
        except:
            if options.verbose: print "Cannot get rowcount from SELECT."
            print "NaN"
        else:
            print "%s" % (rowdata[0][0])
    else:
        if rowdata[0][8] < options.threshold:
            try:
                rowdata = do_sql("SELECT count(*) FROM %s.%s FORCE INDEX (PRIMARY)" % (options.db, options.table))
            except:
                print "%s" % (rowdata[0][8])
            else:
                print "%s" % (rowdata[0][0])
        else:
            print "%s" % (rowdata[0][8])
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

init()

if options.list:
    dbs = do_sql("SHOW DATABASES")
    for db in dbs:
        tables = do_sql("SHOW TABLES FROM %s" % (db))
        if options.list == "dbs":
            print "%s" % (db[0])
            continue
        for table in tables:
            if options.list == "tables":
                print "%s.%s:%s.%s" % (db[0], table[0], db[0], table[0])
            else:
                print "%s.%s" % (db[0], table[0])
    sys.exit(0)

if options.tablesize:
    get_tablesize()
else:
    get_rowcount()
sys.exit(0)

print "Something odd just happened.  Value: %s, Length: %s" % (value, len(value))
if (options.warning is None): print "No Warning threshold"
if (options.critical is None): print "No Critical threshold"
if (options.inverse): print "Inverse mode enabled"
sys.exit(3)
