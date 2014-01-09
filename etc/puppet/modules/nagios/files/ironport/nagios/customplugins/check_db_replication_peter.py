#!/usr/bin/python26

import sys, MySQLdb, getopt, getpass, time
import _mysql_exceptions

start_time = time.time()


def usage():
    print "syntax: %s -H <host> -u <user> -p <password> -d <db> -w <seconds> -c <seconds> [-v <version>]" % (sys.argv[0])
    print "   -v <version> - Valid values: 4.0, 4.1.  Defaults to 4.0"

def closeDB():
    global dbc
    global cursor
    cursor.close()
    dbc.close()

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'H:u:p:d:w:c:v:h')
except getopt.GetoptError, inst:
    usage()
    sys.exit(2)

host = 'localhost'
user = getpass.getuser()
passwd = None
db = None
warningThreshold = None
criticalThreshold = None
version = "4.0"

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
    if opt == '-c':
        criticalThreshold = int(arg)
    if opt == '-w':
        warningThreshold = int(arg)
    if opt == '-v':
        version = arg

if not passwd or not criticalThreshold or not warningThreshold:
    usage()
    sys.exit(2)

if version == "4.0":
    SLAVEIORUNNING  = 9
    SLAVESQLRUNNING = 10

if version == "4.1":
    SLAVEIORUNNING  = 10
    SLAVESQLRUNNING = 11

if version == "5.0":
    SLAVEIORUNNING  = 11
    SLAVESQLRUNNING = 12
try:
    dbc = MySQLdb.connect(user=user, passwd=passwd, db=db, host=host)
except _mysql_exceptions.OperationalError, inst:
    print "MySQL Error:", inst
    usage()
    sys.exit(2)

cursor = dbc.cursor()

cursor.execute("show slave status")

slaveStatus = cursor.fetchone()

if not slaveStatus[SLAVEIORUNNING] == 'Yes':
    print "CRITICAL - Slave IO Thread is not running."
    sys.exit(2)

if not slaveStatus[SLAVESQLRUNNING] == 'Yes':
    print "CRITICAL - Slave SQL Thread is not running."
    sys.exit(2)

cursor.execute("select timestamp from replicationTS where id=1")

timestamp = int(cursor.fetchone()[0])

curTime = int(time.time())

# We take 300 seconds off, since the row is only updated every 5 minutes
drift = curTime - timestamp - 120

if drift < 0: drift = 0

end_time = time.time()

total_time = end_time - start_time

if drift > criticalThreshold:
    print "CRITICAL - Slave drift %d is greater than threshold %d. | run_time=%-.3f" % (drift, criticalThreshold, total_time)
    closeDB()
    sys.exit(2)

if drift > warningThreshold:
    print "WARNING - Slave drift %d is greater than threshold %d. | run_time=%-.3f" % (drift, warningThreshold, total_time)
    closeDB()
    sys.exit(1)

closeDB()
print "OK - Drift: %d. | run_time=%-.3f" % (drift, total_time)

