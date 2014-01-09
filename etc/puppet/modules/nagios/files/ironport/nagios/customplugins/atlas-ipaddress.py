#!/usr/bin/python26

# -*- coding: ascii -*-

# Connects to atlas database, alerts if percentage of usable ips greater than thresholds.
# Mike "Shaun" Lindsey <miklinds@ironport.com> 6/8/2009

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
    usage = """usage %prog [options]"""
    parser = OptionParser(usage)
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="MySQL host to connect to.")
    parser.add_option("-d", "--db", type="string", dest="db",
                            default="atlas",
                            help="Database to connect to.")
    parser.add_option("-D", "--datacenter", type="string", dest="datacenter",
                            help="Datacenter ID to check.  All, if not specified.")
    parser.add_option("-u", "--user", type="string", dest="user",
                            help="MySQL user to connect as.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="MySQL password to use.")
    parser.add_option("-c", "--critical", type="float", dest="critical",
                            help="Critical Threshold")
    parser.add_option("-w", "--warning", type="float", dest="warning",
                            help="Warning Threshold")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    global options
    (options, args) = parser.parse_args()
    exitflag = 0
    if not options.host:
        exitflag = 1
	print "--host is not optional"
    if not options.user:
        exitflag = 1
	print "--user is not optional"
    if not options.password:
        exitflag = 1
	print "--password is not optional"
    if not options.critical:
        print "--critical is not optional"
	exitflag = 1
    elif not options.warning:
        print "--warning is not optional"
	exitflag = 1
    elif options.critical <= options.warning:
        print "critical must be greater than warning."
        exitflag = 1
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

if options.datacenter:
    try:
        name = do_sql("SELECT name FROM atlas_datacenter WHERE id=%s" % (options.datacenter))[0][0]
    except:    
        print "Unknown connection or select error, grabbing datacenter name."
        sys.exit(exit['unkn'])

sql = "SELECT count(*) FROM atlas_ipaddress WHERE (interface_id IS NULL OR interface_type IS NULL)"
if options.datacenter: sql += "and data_center_id=%s" % (options.datacenter)
try:
    available = float(do_sql(sql)[0][0])
except:
    print "Unknown connection or select error grabbing available numbers."
    sys.exit(exit['unkn'])

sql = "SELECT count(*) FROM atlas_ipaddress WHERE (interface_id IS NOT NULL AND interface_type IS NOT NULL)"
if options.datacenter: sql += "and data_center_id=%s" % (options.datacenter)
try:
    used = float(do_sql(sql)[0][0])
except:
    print "Unknown connection or select error grabbing used numbers."
    sys.exit(exit['unkn'])

percent = (100/(used+available))*used

if options.datacenter:
    print "Colo %s " % (name),
print "Atlas IP allocation at %d%%" % (percent)
if percent >= options.critical:
    sys.exit(2)
elif percent >= options.warning:
    sys.exit(1)
else:
    sys.exit(0)

print "Something odd just happened."
sys.exit(3)
