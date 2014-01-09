#!/usr/bin/env python26

#  run  from nagios the following checks
# $PATH_TO_CHECK/kelvin_health.py -H $HOST$ -c lag
# half hour
# $PATH_TO_CHECK/kelvin_health.py -H $HOST$ -c package
# hourly
# $PATH_TO_CHECK/kelvin_health.py -H $HOST$ -c cleaner
# daily or hourly
# send all notifications to support group in the support document

from sys import exit
from optparse import OptionParser
from time import time
import signal

CRITICAL = 2
WARNING = 1
OK = 0
UNKNOWN = -1
CHECK_TIMEOUT = 10

def timedout(signum, frame):
  import sys
  print "CRITICAL: check has timed out in %d seconds" %(CHECK_TIMEOUT)
  sys.exit(CRITICAL)

############################################################
# Kelvin health checks
class qkelvin:

  def __init__(self, host, user, passwd):
    import MySQLdb
    self.host = host
    try:
      self.conn = MySQLdb.connect (host = self.host,
                                  user = user,
                                  passwd = passwd,
                                  db = "kelvin")
    except:
      print "CRITICAL: Could not connect to %s" %(self.host)
      exit(CRITICAL)
  
  def check_lag(self, warn, crit, now):
    exitCode = UNKNOWN
    exitString = "An unknown error occured in check_lag"
    a = self.conn.cursor()
    myquery = "select MAX(unixtime) as latest from sbnp_ipas_mga_hits"
    a.execute(myquery)
    row = a.fetchall()
    try:
      maxTS = int(row[0][0])
      if now - maxTS >= crit:
        exitCode = CRITICAL
        exitString = "CRITICAL: Lag is greater than %s seconds" %(crit)
      elif now - maxTS >= warn:
        exitCode = WARNING
        exitString = "WARNING: Lag is greater than %s seconds" %(warn)
      else:
        exitCode = OK
        exitString = "OK: Lag is OK"
    except:
      exitCode = CRITICAL
      exitString = "CRITICAL: could not obtain data from sbnp_ipas_mga_hits"
    a.close()
    return(exitCode, exitString)

  def check_package(self, warn, crit, now):
    exitCode = UNKNOWN
    exitString = "An unknown error occured in check_package"
    a = self.conn.cursor()
    myquery = "select MAX(ctime) as latest from packages"
    a.execute(myquery)
    row = a.fetchall()
    try:
      maxTS = int(row[0][0])
      if now - maxTS >= crit:
        exitCode = CRITICAL
        exitString = "CRITICAL: Package lag is greater than %s seconds" %(crit)
      elif now - maxTS >= warn:
        exitCode = WARNING
        exitString = "WARNING: Package lag is greater than %s seconds" %(warn)
      else:
        exitCode = OK
        exitString = "OK: Package lag is OK"
    except:
      exitCode = CRITICAL
      exitString = "CRITICAL: could not obtain data from packages table"
    a.close()
    return(exitCode, exitString)

  def check_cleaner(self, warn, crit, now):
    exitCode = UNKNOWN
    exitString = "An unknown error occured in check_cleaner"
    a = self.conn.cursor()
    myquery = "select  MIN(unixtime) as latest from sbnp_ipas_mga_hits"
    a.execute(myquery)
    row = a.fetchall()
    try:
      maxTS = int(row[0][0])
      if now - maxTS >= crit:
        exitCode = CRITICAL
        exitString = "CRITICAL: cleaner lag is greater than %s seconds" %(crit)
      elif now - maxTS >= warn:
        exitCode = WARNING
        exitString = "WARNING: cleaner lag is greater than %s seconds" %(warn)
      else:
        exitCode = OK
        exitString = "OK: Cleaner is OK"
    except:
      exitCode = CRITICAL
      exitString = "CRITICAL: could not obtain data from sbnp_ipas_mga_hits table"
    a.close()
    return(exitCode, exitString)

  def closedb(self):
    self.conn.close()

############################################################

if __name__ == "__main__":
  parser = OptionParser()
  parser.add_option("-H", "--host", dest="host",help="\nDatabase host to query", metavar="KELVIN_DB")
  parser.add_option("-c", "--check", dest="check",help="\nKelvin check to perform: package, lag, cleaner", metavar="KELVIN_CHECK")
  parser.add_option("-u", "--user", dest="user",help="\nDB Username to connect with")
  parser.add_option("-p", "--passwd", dest="passwd",help="\nDB Password to use")
  (options, args) = parser.parse_args()
  now = int(time())

  if not options.host or not options.check:
    print "Run with -h for usage"

  RETURN_CODE = UNKNOWN
  STATUS_STRING = "Unknown error has occured"

  kelvin_health = qkelvin(options.host, options.user, options.passwd)

  signal.signal(signal.SIGALRM, timedout)
  signal.alarm(CHECK_TIMEOUT)

  if options.check == 'lag':
# lag 3 hours warn / 9 hours crit
    (RETURN_CODE, STATUS_STRING) = kelvin_health.check_lag(10800, 32400, now)
  if options.check == 'package':
# lag 1 day warn / 2 days crit
    (RETURN_CODE, STATUS_STRING) = kelvin_health.check_package(86400, 172800, now)
# lag 4 days older than 7 is warn / 7 days older than 7 is crit
  if options.check == 'cleaner':
    (RETURN_CODE, STATUS_STRING) = kelvin_health.check_cleaner(345600, 604800, (now - 604800))

  kelvin_health.closedb()
  print STATUS_STRING
  signal.alarm(0)
  exit(RETURN_CODE)
