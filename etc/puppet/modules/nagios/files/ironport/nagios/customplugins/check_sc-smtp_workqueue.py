#!/usr/bin/python26

import urllib, sys, optparse, time, getpass
import xml.dom.minidom

optParser = optparse.OptionParser()


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

workQTotal = 0

execute_start = time.time()

for i in [1,2,3,4,5,6]:
    host = "sc-smtp%s.soma.ironport.com" % (i)

    url = "https://%s:%s@%s/xml/status" % (options.user, options.password, host)

    html = ''.join(urllib.urlopen(url).readlines())

    #print html
    dom = xml.dom.minidom.parseString(html)

    for gauge in dom.getElementsByTagName('gauge'):
        if gauge.attributes['name'].value == u'msgs_in_work_queue':
            workQCount = int(gauge.attributes['current'].value)
            workQTotal = int(workQTotal + workQCount)
            break

execute_time = time.time() - execute_start

if workQTotal > options.critical:
    print "CRITICAL - %d messages in the workqueue. | execute_time=%f" % (workQTotal, execute_time)
    sys.exit(2)

if workQTotal > options.warning:
    print "WARNING - %d messages in the workqueue. | execute_time=%f" % (workQTotal, execute_time)
    sys.exit(1)

print "OK - %d messages in the workqueue. | execute_time=%f" % (workQTotal, execute_time)
