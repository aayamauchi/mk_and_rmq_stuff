#!/usr/bin/python26

import urllib2
import simplejson
import sys

try:
    APIHOST = sys.argv[1]
except:
    print 'Usage: %s [XBRS WebAPI HostName]' % sys.argv[0]
    sys.exit(1)

url = 'http://%s/v1/rules?consumer=mon_ops' % APIHOST
conn = urllib2.urlopen(url)
delim = conn.readline()

total_tracking = 0
not_cached = 0
for yaml_doc in conn.read().split(delim):
    packet = simplejson.loads(yaml_doc)
    if 'data' in packet:
        for rule, data in packet['data'].iteritems():
            if data['tracking']:
                total_tracking += 1
                cached = data['cached_genid']
                db_genid = data['last_genid']
            if cached and cached < db_genid:
                not_cached += 1

if total_tracking < 25:
    print "XBRS Rule cache not warm.  %0.2f" % (int(not_cached * 100.0 / float(total_tracking)))
    sys.exit(2)
else:
    print "XBRS Rule cache warm."
    sys.exit(0)
