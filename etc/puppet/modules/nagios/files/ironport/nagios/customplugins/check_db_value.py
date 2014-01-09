#!/usr/bin/python26

import MySQLdb
from optparse import OptionParser

def init():
	parser = OptionParser()
	parser.add_option('-H', '--hostname', type='string', dest='host', help='database host')
	parser.add_option('-d', '--db', type='string', dest='dbname', help='database name')
	parser.add_option('-t', '--table', type='string', dest='dbtable', help='database table')
	parser.add_option('-u', '--user', type='string', dest='dbuser', help='database username')
	parser.add_option('-p', '--pass', type='string', dest='dbpass', help='database password')
	parser.add_option('-q', '--query', type='string', dest='query', help='database query')
	parser.add_option('-c', '--crit', type='string', dest='critical', help='value when critical')
	(options, args) = parser.parse_args()
	return options

options = init()

conn = MySQLdb.connect (user=options.dbuser, passwd=options.dbpass, db=options.dbname, host=options.host)
cursor = conn.cursor()

cursor.execute('SELECT %s FROM %s'% (options.query,options.dbtable))
(value,) = cursor.fetchone()

got = int(value)
cmp = int(options.critical)

if got <= cmp:
	print "2: FAIL - %s is %d"% (options.query,got)
else:
	print "0: OK - %s is %d"% (options.query,got)


