#!/usr/bin/python26


import urllib2
import simplejson
import sys
import pprint

try:
    APIHOST = sys.argv[1]
    ctype = sys.argv[2]
    crit = sys.argv[3]
except:
    print 'Usage: %s <XBRS WebAPI HostName> <daily_requests|errors_pct> <crit> [<warn>]' % sys.argv[0]
    sys.exit(3)

try:
    warn = sys.argv[4]
except:
    warn = None

if ctype not in ['daily_requests', 'errors_pct']:
    print "Unknown request type."
    sys.exit(3)
    

url = 'http://%s/v1/status?consumer=mon_ops' % APIHOST
conn = urllib2.urlopen(url)
delim = conn.readline()

requests = 0
errors_pct = 111
for yaml_doc in conn.read().split(delim):
    packet = simplejson.loads(yaml_doc)
    if 'data' in packet:
        if ctype == 'daily_requests':
            data = packet['data']['webapi']['requests']['day']
        else:
            data = packet['data']['webapi']['errors_pct']['day']

if ':' == crit[-1]:
    crit = int(crit[:-1])
    # less than crit
    if data < crit:
        print "XBRS %s, %s lt %s" % (ctype, data, crit)
        sys.exit(2)
else:
    crit = int(crit)
    # greater than
    if data > crit:
        print "XBRS %s, %s gt %s" % (ctype, data, crit)
        sys.exit(2)

if warn is not None and ':' == warn[-1]:
    warn = int(warn[:-1])
    # less than warn
    if data < warn:
        print "XBRS %s, %s lt %s" % (ctype, data, warn)
        sys.exit(1)
elif warn is not None:
    warn = int(warn)
    # greater than
    if data > warn:
        print "XBRS %s, %s gt %s" % (ctype, data, warn)
        sys.exit(1)

print 'XBRS %s, %s' % (ctype, data)

