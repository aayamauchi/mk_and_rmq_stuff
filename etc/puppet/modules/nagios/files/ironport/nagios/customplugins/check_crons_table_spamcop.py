#!/usr/bin/python26

import sys, MySQLdb, getopt, getpass, time

maxTimeOut = 90 * 60
multiplier = 2
graceTime  = 2 * 60 * 60

def usage():
    print "syntax: %s -H <host> -u <user> -p <password> -d <db> [-n <command>] [-m <critmultiplier>] [-x <critmaximum>]" % (sys.argv[0])
    print "  critmultiplier - The # that the frequency listed in the table is" 
    print "                   multiplied time to determine when a service is" 
    print "                   critical. Defaults to %s." % (multiplier)
    print "  critmaximum    - Time, in seconds, that a service can be late" 
    print "                   before being considered in a critical state."
    print "                   Defaults to %s." % (maxTimeOut)
    print "  If no 'command' is given it will check every command in the crons"
    print "  table and return an error if any are in a bad state."

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'H:u:p:d:n:m:x:h')
except getopt.GetoptError:
    usage()
    sys.exit(2)


command = None
host = 'localhost'
user = getpass.getuser()
passwd = None
db = None

for opt, arg in optlist:
    if opt =='-h':
        usage()
        sys.exit(2)
    if opt =='-H':
        host = arg
    if opt =='-u':
        user = arg
    if opt =='-p':
        passwd = arg
    if opt =='-d':
        db = arg
    if opt == '-n':
        command = arg
    if opt == '-m':
        multiplier = int(arg)
    if opt == '-x':
        maxTimeOut = int(arg)

try:
    dbc = MySQLdb.connect(user=user, passwd=passwd, db=db, host=host)
except:
    print "MySQL Error:", sys.exc_info()[0]
    usage()
    sys.exit(2)

cursor = dbc.cursor()

NAMECOL = 0
FREQCOL = 1
LASTRUNCOL = 2
RUNNOTESCOL = 3
TIMESTAMPCOL = 4
LASTLOGCOL = 5

# XXX verify that LASTRUNCOL will do what we want, else we're fucked.
#if command == None:
#    query = "select name, frequency, lastrun, runnotes, UNIX_TIMESTAMP(), lastlog from crons"
#else:
query = "select name, frequency, lastrun, runnotes, UNIX_TIMESTAMP(), lastlog from crons where name='%s'" % (command)

currentTime = int(time.time())
cursor.execute(query)

errors = []
warnings = []
criticals = []

for row in cursor.fetchall():
    if row[LASTRUNCOL] == None: 
        if not command == None:
            print "WARNING - Command %s has no lastrun value. Disabled?" % (command)
            sys.exit(1)
        continue
    

    if row[TIMESTAMPCOL] - ( multiplier * (2*row[FREQCOL]) + graceTime ) > row[LASTRUNCOL] or row[TIMESTAMPCOL] - ( row[FREQCOL] + maxTimeOut ) > row[LASTRUNCOL]:
        criticals.append(row)

    if row[TIMESTAMPCOL] - ( (2*row[FREQCOL]) + graceTime) > row[LASTRUNCOL]:
        warnings.append(row)

cursor.close()
dbc.close()

if criticals:
    print "CRITICAL -", 
    print "Last successful run @" + time.strftime('%b/%d %I:%M %p', time.localtime(row[LASTRUNCOL])) + ".  Lastlog entry: %s.  Runnotes: %s" % (row[LASTLOGCOL], row[RUNNOTESCOL] or "Null")
    sys.exit(2)
if warnings:
    print "WARNINGS -", 
    print "Last successful run @" + time.strftime('%b/%d %I:%M %p', time.localtime(row[LASTRUNCOL])) + ".  Lastlog entry: %s.  Runnotes: %s" % (row[LASTLOGCOL], row[RUNNOTESCOL] or "Null")
    sys.exit(1)

if command == None:
    print "OK"
    sys.exit(0)

print "OK - %s last ran @ %s." % (command, time.strftime('%b/%d %I:%M %p', (time.localtime(int(row[LASTRUNCOL])))))
