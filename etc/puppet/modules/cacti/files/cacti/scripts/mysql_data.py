#!/usr/bin/python26

# -*- coding: ascii -*-

# Connects to a mysql database and uses very basic data to get back simple values
# Mike "Shaun" Lindsey <miklinds@ironport.com> 

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
    parser = OptionParser()
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="MySQL host to connect to.")
    parser.add_option("-d", "--db", type="string", dest="db",
                            help="Database to connect to.")
    parser.add_option("-u", "--user", type="string", dest="user",
                            help="MySQL user to connect as.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="MySQL password to use.")
    parser.add_option("-t", "--table", type="string", dest="table",
                            help="Table to query")
    parser.add_option("-c", "--column", type="string", dest="column",
                            help="Column to pull")
    parser.add_option("-w", "--where", type="string", dest="where",
                            help="!SV where clause(s) [x=blah|x=blah!y=foo]")
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
    if not options.table:
        exitflag = 1
	print "--table is not optional"
    if not options.column:
        exitflag = 1
	print "--column is not optional"
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
    if options.verbose: print "%s, %s" % (sql, conn)

    cursor.execute(sql)
    val = cursor.fetchall()
    if options.verbose: print "Results: %s" % (val)
    conn.commit()
    conn.close()
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return val

init()
exit = {}
exit['ok'] = 0
exit['warn'] = 1
exit['crit'] = 2
exit['unkn'] = 3

query = "SELECT %s FROM %s" % (options.column, options.table)
if options.where:
    query += " WHERE "
    for where in options.where.split('!'):
        query += "%s AND " % (where)
    query = query[0:-4]

value = do_sql(query)
try:
    value = value[0][0]
except:
    print "NaN"
    sys.exit(exit['unkn'])

if not value: value = 0

print value
