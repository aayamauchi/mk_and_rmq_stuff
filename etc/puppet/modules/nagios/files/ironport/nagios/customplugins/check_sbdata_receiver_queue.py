#!/usr/bin/env python26
"""
Nagios monitor for sbdata queue_state table entries.

:Status: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_sbdata_receiver_queue.py#1 $
:Authors: bberezov
"""

import optparse
import MySQLdb
import MySQLdb.cursors
import sys
import time


USAGE = """
%s -H <host> -u <user> -p <password> -d <db> -c <critical> -w <warning> 

host       - Database host.
user       - Database user.
password   - Database password.
db         - Database name containing the target 'queue_state' table.
critical   - Number of seconds for mtime to rise critical.
warning    - Number of seconds for mtime to rise warning.
""" % (sys.argv[0])


optparser = optparse.OptionParser(usage=USAGE)
optparser.add_option('-H', '--host', dest='host', default=None,
		action='store')
optparser.add_option('-u', '--user', dest='user', default='nagios',
		action='store')
optparser.add_option('-p', '--password', dest='password', default=None,
		action='store')
optparser.add_option('-d', '--db', dest='db', default='receiver_dbq',
		action='store')
optparser.add_option('-c', '--critical', dest='critical', default=None,
		action='store', type="int")
optparser.add_option('-w', '--warning', dest='warning', default=None,
		action='store', type="int")

try:
	(opt, args) = optparser.parse_args()
except optparse.OptParseError, err:
	print err
	sys.exit(2)

if not (opt.host and opt.password and opt.critical):
	print USAGE
	sys.exit(2)

EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

tables = []
criticals = []
warnings  = []
critical = opt.critical
warning = opt.warning

try:
	conn = MySQLdb.connect(user=opt.user, passwd=opt.password, db=opt.db,
			host=opt.host, cursorclass=MySQLdb.cursors.DictCursor)
	cursor = conn.cursor()
except MySQLdb.Error,e:
	print str(e)
	sys.exit(EXIT_CRIT)


now = int(time.time())

query = """SELECT queue_name, pointer_name, table_name, 
		UNIX_TIMESTAMP(mtime) as mtime from queue_state;"""

try:
	cursor.execute(query)
except MySQLdb.Error,e:
	print str(e)
	sys.exit(EXIT_UNK)    

rows = cursor.fetchall()

if len(rows) != 2:
	print "Something is wrong. Should be two rows in table"
	sys.exit(EXIT_UNK)

for row in rows:

	time_since_mtime = now - int(row['mtime'])

	#Extract table number from name
	table_number = row['table_name'].split('_')[2]
	tables.append(table_number)

	if time_since_mtime <= critical and time_since_mtime > warning:
		warnings.append("Pointer '%s.%s' is %s seconds since mtime." % ( row['table_name'],row['pointer_name'],time_since_mtime) )
	if time_since_mtime > critical:
		criticals.append("Pointer '%s.%s' is %s seconds since mtime." % ( row['table_name'],row['pointer_name'],time_since_mtime) )

cursor.close()
conn.close()

# Get difference between in and reader tables
tables_diff = abs(int(tables[0]) - int(tables[1]))

if  tables_diff > 1: 
	criticals.append("Difference between tables greater than 1.")

if criticals:
	print "CRITICAL"
	print (' ').join(criticals)
	sys.exit(EXIT_CRIT)
elif warnings:
	print "WARNING"
	print (' ').join(warnings)
	sys.exit(EXIT_WARN)
else:
	print "OK"
	sys.exit(EXIT_OK)



