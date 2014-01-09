#!/usr/bin/python26

import urllib, sys, optparse, time, getpass
import xml.dom.minidom

optParser = optparse.OptionParser()


optParser.add_option("-H", "--host", dest="host",
                     help="Host you want to check.")
optParser.add_option("-u", "--user", dest="user",
                     help="User to login as.")
optParser.add_option("-p", "--password", dest="password",
                     help="Password to login with.")
optParser.add_option("-w", "--warning", dest="warning", type="int",
                     help="Sets the warning threshold.")
optParser.add_option("-c", "--critical", dest="critical", type="int",
                     help="Sets the critical threshold.")

(options, args) = optParser.parse_args()

errMsgs = []
if options.host == None:
    errMsgs.append("--host")
if options.warning == None:
    errMsgs.append("--warning")
if options.critical == None:
    errMsgs.append("--critical")
if options.user == None:
    errMsgs.append("--user")
if options.password == None:
    errMsgs.append("--password")

if len(errMsgs) > 0:
    print "Missing options: " + ', '.join(errMsgs)
    optParser.print_help()
    sys.exit(1)

url = "https://%s:%s@%s/xml/status" % (options.user, options.password, options.host)

html = ''.join(urllib.urlopen(url).readlines())

#print html
dom = xml.dom.minidom.parseString(html)

for gauge in dom.getElementsByTagName('gauge'):
    if gauge.attributes['name'].value == u'msgs_in_work_queue':
        workQCount = int(gauge.attributes['current'].value)
        break

if workQCount > options.critical:
    print "CRITICAL - %d messages in the workqueue." % (workQCount)
    sys.exit(2)

if workQCount > options.warning:
    print "WARNING - %d messages in the workqueue." % (workQCount)
    sys.exit(1)

print "OK - %d messages in the workqueue." % (workQCount)
