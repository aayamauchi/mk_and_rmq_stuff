#!/usr/bin/env python26

# -*- coding: ascii -*-

# Connects to a mysql database and grabs the processlist
# checking for valid data.
# Mike "Shaun" Lindsey <miklinds@ironport.com> 2/04/2009

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
Filters data from SHOW FULL PROCESSLIST, and checks time against crit and warn thresholds.
If neither is given, then ANY threads matching criteria will cause an alert.
Other than the infofilter, filters can be inverted by prepending !"""
    parser = OptionParser(usage)
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="MySQL host to connect to.")
    parser.add_option("-u", "--user", type="string", dest="user",
                            help="MySQL user to connect as.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="MySQL password to use.")
    parser.add_option("-D", "--dbfilter", type="string", dest="dbfilter",
                            help="Only match threads using this database.")
    parser.add_option("-N", "--hostnamefilter", type="string", dest="hostfilter",
                            help="Only match threads from his hostname.")
    parser.add_option("-U", "--userfilter", type="string", dest="userfilter",
                            help="Only match threads by this user")
    parser.add_option("-C", "--commandfilter", type="string", dest="commandfilter",
                            help="Only match threads running this command")
    parser.add_option("-S", "--statefilter", type="string", dest="statefilter",
                            help="Only match threads by in this state")
    parser.add_option("-I", "--infofilter", type="string", dest="infofilter",
                            help="Only match threads running this query. Allows partial match, ie 'SHOW FULL' will match 'SHOW FULL PROCESSLIST'.  Filter and data are lowercased first for your ease.")
    parser.add_option("-c", "--critical", type="float", dest="critical",
                            help="Critical Threshold")
    parser.add_option("-w", "--warning", type="float", dest="warning",
                            help="Warning Threshold")
    parser.add_option("--cacti", action="store_true", dest="cacti",
                            default=False,
			    help="Print out cacti data instead of nagios data.")
    parser.add_option("-P", "--print", action="store_true", dest="printthread",
                            default=False,
                            help="print matching threads to stdout")
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
    if (options.critical is not None and options.warning is not None) and (options.warning >= options.critical):
        print "Critical must be greater than Warning"
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

def init_db(database):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    try:
        conn = MySQLdb.connect (host = options.host,
                            user = options.user,
                            db = database,
                            passwd = options.password)
    except:
        print "MySQL connect error"
	sys.exit(exit['unkn'])
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return conn

def do_sql(database, sql):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    conn = init_db(database)
    cursor = conn.cursor()
    if options.verbose: print "%s, %s" % (sql, conn)

    cursor.execute(sql)
    val = cursor.fetchall()
    if options.verbose: print "Results: %s" % (str(val))
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
warning = 0
critical = 0
count = 0
time = 0
maxtime = 0

processlist = {}

for val in do_sql("mysql", "SHOW FULL PROCESSLIST"):
    if val[1] == 'system user': continue
    if val[1] == 'repl': continue
    if val[4] == 'Sleep': continue
    if options.userfilter:
        if options.userfilter[0] == "!":
            if val[1] == options.userfilter[1::]: continue
	else:
            if val[1] != options.userfilter: continue
    if options.hostfilter:
        if options.hostfilter[0] == "!":
	    if val[2] == options.hostfilter: continue
	else:
	    if val[2] != options.hostfilter: continue
    if options.dbfilter:
        if options.dbfilter[0] == "!":
	    if val[3] == options.dbfilter: continue
	else:
	    if val[3] != options.dbfilter: continue
    if options.commandfilter:
        if options.commandfilter[0] == "!":
	    if val[4] == options.commandfilter: continue
	else:
	    if val[4] != options.commandfilter: continue
    if options.statefilter:
        if options.statefilter[0] == "!":
	    if val[6] == options.statefilter: continue
	else:
	    if val[6] != options.statefilter: continue
    if options.infofilter:
        if not val[7]: continue
        if val[7][0:len(options.infofilter)].lower() != options.infofilter.lower():
	    continue
    x = {}
    if options.cacti:
        count += 1
	if val[5] > maxtime: maxtime = val[5]
	time += val[5]
    if options.warning and val[5] < options.warning:
        continue
    elif options.warning:
        warning = 1
	x['warning'] = 1
    if options.critical and val[5] < options.critical and not options.warning:
	continue
    elif options.critical and val[5] >= options.critical:
	x['critical'] = 1
	critical = 1
    x['user'] = val[1]
    x['host'] = val[2]
    x['db'] = val[3]
    x['command'] = val[4]
    x['time'] = val[5]
    x['state'] = val[6]
    x['info'] = val[7]
    for key in x.keys():
        if key is None: x[key] = ''
    
    processlist[val[0]] = x


if options.cacti:
    print "avgtime:%s maxtime:%s threads:%s" % (time/count, maxtime, count)
    sys.exit(3)
warnpids = ''
critpids = ''
pids = ''
for pid in processlist: 
    if processlist[pid].has_key('critical'): critpids += '%s,' % (pid)
    elif processlist[pid].has_key('warning'): warnpids += '%s,' % (pid)
    pids += '%s,' % (pid)
warnpids = warnpids[:-1]
critpids = critpids[:-1]
pids = pids[:-1]

if critical:
    print "CRITICAL threads matching thresholds: %s" % (critpids),
    if warning: print " WARN threshold for: %s" % (warnpids),
    print
elif warning:
    print "WARNING threads matching thresholds: %s" % (warnpids)
else:
    if pids:
        print "CRITICAL threads matching filters: %s" % (pids)
	critical = 1
    else:
        print "OK no threads matching criteria"

if options.printthread:
    for process in processlist:
        print "%10s | %14s | %14s | %10s | %10s" % ('Id', 'User', 'Host', 'Db', 'Command')
        print "%10.10s | %14.14s |" % (process, processlist[process]['user']),
        print "%14.14s | %10.10s | %10.10s" % (processlist[process]['host'], processlist[process]['db'], processlist[process]['command'])
        print "%10s | %14s | %12s" % ('Time', 'State', 'Info')
        print "%10.10s |" % (processlist[process]['time']),
        print "%14.14s | %12s" % (processlist[process]['state'], processlist[process]['info'])
    for process in processlist:
	print "EXPLAIN output for %s" % (process)
	rows = ''
        try:
	    rows = do_sql(processlist[process]['db'], "EXPLAIN %s" % (processlist[process]['info']))
	except:
	   print "NONE"
        else:
            for row in rows:
                print "%16s: %s" % ('id', row[0])
	        print "%16s: %s" % ('select_type', row[1])
	        print "%16s: %s" % ('table', row[2])
	        print "%16s: %s" % ('type', row[3])
	        print "%16s: %s" % ('possible_keys', row[4])
	        print "%16s: %s" % ('key', row[5])
	        print "%16s: %s" % ('key_len', row[6])
	        print "%16s: %s" % ('ref', row[7])
	        print "%16s: %s" % ('rows', row[8])
	        print "%16s: %s" % ('Extra', row[9])



if critical: sys.exit(exit['crit'])
if warning: sys.exit(exit['warn'])
sys.exit(exit['ok'])
