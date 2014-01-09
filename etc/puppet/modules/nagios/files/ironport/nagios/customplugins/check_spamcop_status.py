#!/usr/bin/python26

import urllib, sys

def syntax():
    print "syntax: %s <host> <local|global>" % (sys.argv[0])

if len(sys.argv) < 3 or len(sys.argv) > 3:
    syntax()
    sys.exit(1)

host = sys.argv[1].strip()
scope = sys.argv[2].strip()
url = 'http://' + host + '/status?' + scope

site = urllib.urlopen(url)
data = site.readlines()

if not data[0] == 'all ok':
    print "WARNING - %s" % (data[0])
    sys.exit(1)

print "OK - %s" % (data[0])
