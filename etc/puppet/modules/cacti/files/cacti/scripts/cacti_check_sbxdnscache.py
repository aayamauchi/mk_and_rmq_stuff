#!/usr/bin/python26

import optparse
import sys
import traceback
import urllib2
import os
os.environ['PYTHON_EGG_CACHE'] = '/tmp'
try:
    import simplejson
except:
    print "5"
    f = open('/tmp/out.txt', 'w')
    print >>f, sys.exc_info()[0]
    print >>f, sys.exc_info()[1]
    print >>f, "LINE=",traceback.tb_lineno(sys.exc_info()[2])
    f.close()

    sys.exit(1)

usage = """%prog [options] <hostname>"""
cmdparser = optparse.OptionParser(usage=usage)
cmdparser.add_option('-p', '--port', default=9000, type="int",
        help="Port to query for values.  Default: 9000.")
cmdparser.add_option('-v', '--variable',
        help="Variable to print")

# Error is before this line

try:
    (options, args) = cmdparser.parse_args()
except optparse.OptParseError:
    print "Error: Invalid command line arguments."
    cmdparser.print_help()
    traceback_print_exc()
    sys.exit(1)


try:
    host = args[0]
except IndexError:
    print "Error: No host specified."
    cmdparser.print_help()
    sys.exit(1)

url = "http://%s:%d/sbxdnscache/stats/?format=json" % (host, options.port)

url_data = urllib2.urlopen(url)

stats = simplejson.load(url_data)[0]['sbxdnscache']['stats']

queries_keys = ['cached', 'invalid', 'nxdomain', 'queries']
rates_keys = ['cache hit%', 'hash search len', 'load shed max', 
        'cache evictions per second', 'response_ms']
rates_keyvalue = {'cache hit%': 'hitpcnt', 'hash search len': 'hashsearchlen', 'load shed max': 'loadshedmax', 
        'cache evictions per second': 'cacheevictionspersec', 'response_ms': 'responsems'}


if options.variable:
    for i in queries_keys:
        if i == options.variable: print str(stats['queries'][i]),

    for i in rates_keys:
        if rates_keyvalue[i] == options.variable: print str(stats['rates'][i]['5m']),

else:
    for i in queries_keys:
        print "%s:%d" % (i, stats['queries'][i]),

    for i in rates_keys:
        print "%s:%-.2f" % (rates_keyvalue[i], stats['rates'][i]['5m']),

