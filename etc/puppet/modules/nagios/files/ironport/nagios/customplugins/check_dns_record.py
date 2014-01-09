#!/usr/bin/python26

import DNS
import sys
import getopt
import re
import socket
import optparse
import time

execute_start = time.time()

def getDNSServers():
    nameServers = []
    try:
        for line in [x.split() for x in open('/etc/resolv.conf').readlines()]:
            try:
                if line[0] == 'nameserver':
                    return line[1]
            except IndexError:
                # Blank line, ignore
                pass
        
        return None
    except IOError:
        return None


optParser = optparse.OptionParser()

optParser.add_option('-H', '--host', dest="host", default=None,
                     help="Host to lookup.")
optParser.add_option('-t', '--type', dest="qtype", default="A",
                     help="Type of record to lookup.  Defaults to 'A'.")
optParser.add_option('-s', '--server', dest="server", 
                     default=getDNSServers() or 'localhost',
                     help="Server to use for the lookup.  Defaults to using /etc/resolv.conf.")
optParser.add_option('-r', '--regexp', dest="regexpStr", default=".*",
                     help="Regular expression to match reply against.")

(options, args) = optParser.parse_args()

if not options.host or not options.server:
    optParser.print_help()
    sys.exit(1)

regexp = re.compile(options.regexpStr)

req = DNS.Request()

try:
    query = req.req(name=options.host,
                    server=options.server,
                    qtype=options.qtype,
                    timeout=5)
    execute_time = time.time() - execute_start
except socket.error:
    print "CRITICAL - Could not contact server '%s'." % (options.server)
    sys.exit(2)
except DNS.Base.DNSError:
    print "CRITICAL - Could not contact server '%s'." % (options.server)
    sys.exit(2)

try: 
    data = query.answers[0]['data'][0]
except IndexError:
    print "CRITICAL - No '%s' record found for %s. | execute_time=%f" % (options.qtype, options.host, execute_time)
    sys.exit(2)

if regexp.search(data):
    print "OK - Response matched regexp '%s' | execute_time=%f" % (options.regexpStr, execute_time)
    print "Response: %s" % (data)
    sys.exit(0)
else:
    print "CRITICAL - Response does not match regexp '%s' | execute_time=%f" % (options.regexpStr, execute_time)
    print "Response: %s" % (data)
    sys.exit(2)
