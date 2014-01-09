#!/usr/bin/python26

import urllib2, sys, getopt, time, getpass
from urlparse import urlparse
import xml.dom.minidom

def usage():
    print "syntax: %s -H <host> -p <password> [-u <user>] [-w <warning>] [-c <critical>] [-r <realm>]" % (sys.argv[0])

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'H:u:p:w:c:h')
except getopt.GetoptError:
    usage()
    sys.exit(2)

host = None
user = getpass.getuser()
passwd = None
warning = None
critical = None
realm = "IronPort Web Interface"

for opt, arg in optlist:
    if opt == '-h':
        usage()
        sys.exit(2)
    if opt == '-H':
        host = arg
    if opt == '-u':
        user = arg
    if opt == '-p':
        passwd = arg
    if opt == '-w':
        warning = int(arg)
    if opt == '-c':
        critical = int(arg)

if not host or not passwd:
    usage()
    sys.exit(2)

url = 'http://%s/xml/status' % (host)

# If no warning set, set it to 15 minutes
if not warning: warning = 15 * 60
# if no critical set, set it to twice warning
if not critical: critical = warning *2

# Make your http auth handler object
handler = urllib2.HTTPBasicAuthHandler()
handler.add_password(realm,host,user,passwd)

# now make the http opener object
opener = urllib2.build_opener(handler)
urllib2.install_opener(opener)

try:
    client = urllib2.urlopen(url)
except urllib2.HTTPError, e:
    print "CRITICAL - HTTPError: %d" % (e.code or 'unknown')
    sys.exit(2)

html = ''.join(client.readlines())
#timestamp = html[1].strip().split('timestamp=')[1][1:-2]  
dom = xml.dom.minidom.parseString(html)
statusElement = dom.getElementsByTagName('status')[0]
timestamp = statusElement.getAttribute('timestamp')
unixTimestamp = int(time.strftime('%s',time.strptime(timestamp,'%Y%m%d%H%M%S')))

drift = int(time.time()) - unixTimestamp

if abs(drift) > critical:
    print "CRITICAL - Drift (%d) greater than threshold %d." % (drift, critical)
    sys.exit(2)

if abs(drift) > warning:
    print "WARNING - Drift (%d) greater than threshold %d." % (drift, warning)
    sys.exit(1)

print "OK - Drift (%d) is less than threshold %d." % (drift, warning)
