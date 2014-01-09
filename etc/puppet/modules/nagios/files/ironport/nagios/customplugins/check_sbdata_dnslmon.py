#!/usr/bin/python26
"""
Nagios monitor for sbdata dnslmon table entries.

:Status: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_sbdata_dnslmon.py#1 $
:Authors: bberezov
"""

import optparse
import MySQLdb
import MySQLdb.cursors
import sys
import traceback
import time


USAGE = """
%s -H <host> -u <user> -p <password> -d <db> -c <critical>

host       - Database host.
user       - Database user.
password   - Database password.
db         - Database name containing the target 'crons' table.
critical   - Number of seconds since last checking or query before 
			 critical alert is raised.
""" % (sys.argv[0])


EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

optparser = optparse.OptionParser(usage=USAGE)
optparser.add_option('-H', '--host', dest='host', default=None,
		action='store')
optparser.add_option('-u', '--user', dest='user', default=None,
		action='store')
optparser.add_option('-p', '--password', dest='password', default=None,
		action='store')
optparser.add_option('-d', '--db', dest='db', default=None,
		action='store')
optparser.add_option('-c', '--critical', dest='critical', default=None,
		action='store', type="int")

try:
	(opt, args) = optparser.parse_args()
except optparse.OptParseError, err:
	print err
	sys.exit(EXIT_UNK)

if not (opt.host and opt.user and opt.password and opt.db):
	print USAGE
	sys.exit(EXIT_UNK)


criticals = []
critical = opt.critical

try:
	conn = MySQLdb.connect(user=opt.user, passwd=opt.password, db=opt.db,
			host=opt.host, cursorclass=MySQLdb.cursors.DictCursor)
	cursor = conn.cursor()
except MySQLdb.Error, e:
	print "CRITICAL: Can not execute query: %s" % (e)
	sys.exit(EXIT_CRIT)


now = int(time.time())

query = """SELECT 
		srcid, status, UNIX_TIMESTAMP(last_checkin) as last_checkin, 
		UNIX_TIMESTAMP(last_query) as last_query, avg_queries, pkt_loss 
		from dnslmon;"""

try:
	cursor.execute(query)
except MySQLdb.Error:
	print "Error cant execute query"
	sys.exit(EXIT_UNK)

rows = cursor.fetchall()

for row in rows:
	if row['status'] != 'Running':
		criticals.append("%s status is %s" % (row['srcid'],row['status']))

	time_since_checkin = now - int(row['last_checkin'])
	time_since_query = now - int(row['last_query'])

	if row['status'] == 'Running' and time_since_checkin > critical:
		criticals.append("src %s is %s seconds since last checkin " % ( row['srcid'],time_since_checkin) )
	if row['status'] == 'Running' and time_since_checkin < critical and time_since_query > critical:
		criticals.append("src %s is %s seconds since last query " % ( row['srcid'],time_since_query) )

cursor.close()
conn.close()


if criticals:
	print "CRITICAL"
	print ('\n').join(criticals)
	sys.exit(EXIT_CRIT)
else:
	print "OK"
	sys.exit(EXIT_OK)



