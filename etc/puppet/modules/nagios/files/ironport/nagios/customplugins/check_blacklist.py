#!/usr/bin/python26

import sys, DNS, getopt, time

def usage():
    print "syntax: %s -H <server> -w <warning> -c <critical> -z <zone>" % (sys.argv[0])

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'H:w:c:z:h')
except getopt.GetoptError:
    usage()
    sys.exit(2)


server = None
warning = None
critical = None
zone = None

for opt, arg in optlist:
    if opt == '-h':
        usage()
        sys.exit(2)
    if opt == '-H':
        server = arg
    if opt == '-z':
        zone = arg
    if opt == '-w':
        warning = int(arg)
    if opt == '-c':
        critical = int(arg)

if not (server and zone and warning and critical):
    usage()
    sys.exit(2)

try:
    query = "gen_time." + zone
    answer = DNS.Base.DnsRequest(query, qtype='txt', server=server).req().answers[0]
except:
    print "CRITICAL - DNS Error:", sys.exc_info()
    usage()
    sys.exit(2)

curTime = int(time.time())
mirrorTime = int(answer['data'][0])

drift = abs(curTime - mirrorTime)

if drift > critical:
    print "CRITICAL - Blacklist timestamp (%d) has drifted more than %d seconds." % (mirrorTime, critical)
    sys.exit(2)

if drift > warning:
    print "WARNING - Blacklist timestamp (%d) has drifted more than %d seconds." % (mirrorTime, warning)
    sys.exit(1)

print "OK - Blacklist timestamp: %d. Absolute drift: %d." % (mirrorTime,drift)
