#!/usr/bin/python26

import sys, MySQLdb, getopt, getpass, time
import _mysql_exceptions

start_time = time.time()


def usage():
    print "syntax: %s -H <host> -u <user> -p <password> -d <db> -w <seconds> -c <seconds>" % (sys.argv[0])

def closeDB():
    global dbc
    global cursor
    cursor.close()
    dbc.close()

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'H:u:p:d:w:c:h')
except getopt.GetoptError, inst:
    usage()
    sys.exit(2)

host = 'localhost'
user = getpass.getuser()
passwd = None
db = None
warningThreshold = None
criticalThreshold = None

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

if not passwd or not criticalThreshold or not warningThreshold:
    usage()
    sys.exit(2)

try:
    dbc = MySQLdb.connect(user=user, passwd=passwd, db=db, host=host)
except _mysql_exceptions.OperationalError, inst:
    print "MySQL Error:", inst
    usage()
    sys.exit(2)

cursor = dbc.cursor()

cursor.execute("select unix_timestamp() - end_ts from history_importer_ledger order by change_id desc limit 1")

timestamp = int(cursor.fetchone()[0])

end_time = time.time()

total_time = end_time - start_time

if timestamp > criticalThreshold:
    print "CRITICAL - History DB lag %d seconds is greater than threshold %d. | db_lag=%d;%d;%d; run_time=%-.3f" % (timestamp, criticalThreshold, timestamp, warningThreshold, criticalThreshold, total_time)
    closeDB()
    sys.exit(2)

if timestamp > warningThreshold:
    print "WARNING - History DB lag %d seconds is greater than threshold %d. | db_lag=%d;%d;%d; run_time=%-.3f" % (timestamp, warningThreshold, timestamp, warningThreshold, criticalThreshold, total_time)
    closeDB()
    sys.exit(1)

closeDB()
print "OK - History DB lag %d seconds is less than threshold %d. | db_lag=%d;%d;%d; run_time=%-.3f" % (timestamp, warningThreshold, timestamp, warningThreshold, criticalThreshold, total_time)

