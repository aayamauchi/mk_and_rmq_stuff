#!/usr/bin/python26

import sys, MySQLdb, getopt, getpass, array

def usage():
    print "syntax: %s  -p <password> [-H <host>] [-u <user>] [-w <warning%%>] [-c <critical%%>]" % (sys.argv[0])
    print "  Defaults:"
    print "    host:     %s" % (host)
    print "    user:     %s" % (user)
    print "    warning:  50%"
    print "    critical: 75%"

host = 'localhost'
user = getpass.getuser()
passwd = None
db = None
warning = .5 
critical = .75

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'H:u:p:w:c:h')
except getopt.GetoptError:
    usage()
    sys.exit(2)

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
    if opt == '-w':
        if '%' in arg: warning = float(arg.strip('%'))/100.0
        else: warning = float(arg)/100.0
    if opt == '-c':
        if '%' in arg: critical = float(arg.strip('%'))/100.0
        else: critical = float(arg)/100.0

try:
    dbc = MySQLdb.connect(user=user, passwd=passwd, host=host)
except:
    print "Connect Error:", sys.exc_info()[0]
    usage()
    sys.exit(2)

cursor = dbc.cursor()

query = "show variables"

cursor.execute(query)

for (mysqlVar, val) in cursor.fetchall():
    if mysqlVar == 'max_connections': 
        if type(val) == array.ArrayType:
            maxConnections = float(val.tostring())
        if type(val) == type('a'):
            maxConnections = float(val)

        break

query = "show processlist"

cursor.execute(query)

connections = float(len(cursor.fetchall()))

cursor.close()
dbc.close()

fractionUsed = connections/maxConnections
pctUsed = fractionUsed * 100

if fractionUsed > critical:
    print "CRITICAL - Using %.2f%% (%d) of total (%d) available connections." % (pctUsed, connections, maxConnections)
    sys.exit(2)

if fractionUsed > warning:
    print "WARNING - Using %.2f%% (%d) of total (%d) available connections." % (pctUsed, connections, maxConnections)
    sys.exit(1)

print "OK - Using %.2f%% (%d) of total (%d) available connections." % (pctUsed, connections, maxConnections)
