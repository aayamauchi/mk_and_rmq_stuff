#!/usr/bin/env python26

"""
In order to use this, make sure the following have been ran on the master mysql server in the cluster:

create database sysops;
use sysops;
create table replicationTS (id int not null primary key auto_increment, timestamp int(11) unsigned not null);
grant all privileges on sysops.* to sysops@'%' identified by 'thaxu1T';
"""


import sys, MySQLdb, time, _mysql_exceptions, simplejson, urllib, os
import asdb
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-e", "--environment", type="string", dest="environment",
                            default="prod,stage,int",
                            help="CSV of environments to update")
parser.add_option("-H", "--hostlist", type="string", dest="hostlist",
                            help="CSV of additional hosts to update, treated as env=prod")
(options, args) = parser.parse_args()

dbmlist = ['dbm']

dbMasters = []
hostEnv = {}

for e in options.environment.split(','):
    hosts = asdb.cache('dblist', (e, None, 'dbm', True))
    for host in hosts:
        hostEnv[host] = e
        dbMasters.append(host)

if options.hostlist is not None:
    for host in str(options.hostlist).split(','):
        dbMasters.append(host)
        hostEnv[host] = 'prod'

db = 'sysops'
user = 'sysops'
passwd = 'thaxu1T'

timestamp = int(time.time())

for host in dbMasters:
    pidfile = '/tmp/update-repl.%s.%s.pid' % (hostEnv[host], host)
    if (os.path.exists(pidfile)):
        print "Found pidfile for %s from previous run" % (host)
        try:
            os.kill(int(open(pidfile).read()), 0)
        except:
            os.remove(pidfile)
        else:
            print "Previous update failed for %s" % (host)
	    continue

for host in dbMasters:
    pidfile = '/tmp/update-repl.%s.%s.pid' % (hostEnv[host], host)
    pid = os.fork()
    if pid:
    	slept = 0
	while slept < 10:
            time.sleep(0.5)
	    slept += 0.5
  	    if (os.waitpid(pid, os.WNOHANG) == (0,0)):
	        if slept == 10:
	            print "[%s] Failure to return from update for %s" % (pid, host)
	            os.kill(pid, 9)
	    else:
	        slept = 10
    else:
        pidf = open(pidfile, 'w')
	pidf.write(str(os.getpid()))
	pidf.close()
	error = 0
        try:
            dbc = MySQLdb.connect(user=user, passwd=passwd, db=db, host=host)
            dbc.autocommit(1)
            cursor = dbc.cursor()
            try:
                cursor.execute("truncate replicationTS")
            except _mysql_exceptions.OperationalError, err:
                print "Error: %s on host %s" % (str(err), host)
		error = 1
            except _mysql_exceptions.ProgrammingError, err:
                print "Error: %s on host %s" % (str(err), host)
		error = 1
            else:
	    	print "=== Updating %s." % (host)
	        try:
                    cursor.execute("insert into replicationTS values (1, %s)", (timestamp))
                except:
	            print "Failure to update %s" % (host)
		    error = 1
            cursor.close()
            dbc.close()
        except _mysql_exceptions.OperationalError, err:
            print "Error: %s on host %s" % (str(err), host)
	    error = 1
	if (os.path.exists(pidfile)) and (error == 0):
	    try:
	        os.remove(pidfile)
	    except:
	        break
	break

