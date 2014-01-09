#!/usr/bin/python26
#========================================================================
# check_redlist_counter.py
#
# Redlist 1.5 counter monitor.
# http://eng.ironport.com/docs/is/redlist/1.5/eng/deployment.rst#monitoring
#
# Retrieves counters via rpc. Requires eng-supplied sharedrpc.py.
# Operates in cacti mode with --cacti, in which case thresholds are
# ignored and the value of the counter is returned as value:float.
# Otherwise it assumes nagios operation and requires valid thresholds.
# If --age argument is passed, the age of the counter is checked against
# thresholds (based on a local cache of counter values). Otherwise,
# the counter value is checked against thresholds.
# 
# 2013-03-06 jramache
# 2013-03-19 jramache, added --age arg
#========================================================================
import json as simplejson, urllib2, pprint, time
import sys, os, urllib2, pprint, time
#from shared.rpc.client import FastRPCClient as fastrpc_client
from sharedrpc import FastRPCClient as fastrpc_client
from optparse import OptionParser

def getcode(addinfourl):
    """Get HTTP return code in a python library version independent way"""
    if hasattr(addinfourl, 'code'):
        return addinfourl.code
    return addinfourl.getcode()

parser = OptionParser()
parser.add_option("--host", type="string", dest="host",
                        default=None, help="Host to collect counters from")
parser.add_option("--port", type="int", dest="port",
                        default=11080, help="Http port where active node checked or counters can be retrieved (if force)")
parser.add_option("--counter", type="string", dest="counter",
                        default=None, help="Counter name")
parser.add_option("--warning", type="float", dest="warning",
                        default=None, help="Warning threshold for counter")
parser.add_option("--critical", type="float", dest="critical",
                        default=None, help="Critical threshold for counter")
parser.add_option("--inverse", dest="inverse", action="store_true",
                        default=False, help="Inverse threshold comparisons")
parser.add_option("--age", dest="age", action="store_true",
                        default=False, help="Monitor age of counter last update rather than value.")
parser.add_option("--defaultvalue", type="float", dest="defaultvalue",
                        default=None, help="Default value for the counter if it doesn't exist.")
parser.add_option("--force", dest="force_check", action="store_true",
                        default=False, help="Force counter check from host provided. Skip active node check.")
parser.add_option("--cacti", dest="cacti", action="store_true",
                        default=False, help="Output data suitable for consumption by cacti")
parser.add_option("--verbose", dest="verbose", action="store_true",
                        default=False, help="Verbose output")
(options, args) = parser.parse_args()

if not options.cacti:
    if options.verbose:
        print ">>>>> Operating in nagios mode: verifying thresholds"
    try:
        warn_threshold = float(options.warning)
    except:
        print "UNKNOWN - Invalid or missing warning threshold"
        sys.exit(3)
    try:
        crit_threshold = float(options.critical)
    except:
        print "UNKNOWN - Invalid or missing critical threshold"
        sys.exit(3)

    if not options.inverse and (warn_threshold > crit_threshold):
        print "UNKNOWN - Warning threshold must be less than critical threshold"
        sys.exit(3)
    elif options.inverse and (warn_threshold < crit_threshold):
        print "UNKNOWN - Critical threshold must be less than warning threshold in Inverse mode"
        sys.exit(3)
else:
    if options.verbose:
        print ">>>>> Operating in cacti mode"


# First get active node
if options.force_check:
    active_node_host = options.host
    active_node_port = options.port
else:
    url = "http://%s:%d/nodes_connected?service=active" % (options.host, options.port)
    req = urllib2.Request(url)
    try:
        if options.verbose:
            print ">>>>> Opening connection to %s" % (url)
        http_connection = urllib2.urlopen(url)
        code = getcode(http_connection)
        if code >= 400:
            print "CRITICAL - Problem accessing active node URL %s . " \
                "Server returned HTTP CODE %d ." % (url, code)
            sys.exit(2)
    except Exception, e:
        print "CRITICAL - Problem accessing active node URL %s : %s" % (url, e)
        sys.exit(2)

    try:
        if options.verbose:
            print ">>>>> Parsing data returned from http connection"
        data = http_connection.readlines()
        active_node = data[0].split()[0]
    except:
        print "CRITICAL - Invalid http data returned from server"
        sys.exit(2)

    try:
        active_node_host = active_node.split(':')[0]
    except:
        print "CRITICAL - Invalid active host name returned from server"
        sys.exit(2)
    try:
        active_node_port = float(active_node.split(':')[1])
    except:
        print "CRITICAL - Invalid active port number returned from server"
        sys.exit(2)
    else:
        active_node_port = int(active_node_port)

# Next retrieve counter value from active node
try:
    if options.verbose:
        print ">>>>> Opening rpc connection to %s:%d" % (active_node_host, active_node_port)
    client = fastrpc_client((active_node_host, active_node_port)).get_proxy()
except:
    print "CRITICAL - Problem opening rpc connection to %s:%d" % (active_node_host, active_node_port)
    sys.exit(2)

try:
    if options.verbose:
        print ">>>>> Loading json from rpc client"
    data = simplejson.loads(client.counters())
except:
    print "CRITICAL - Invalid data returned from server (unable to parse json)"
    sys.exit(2)

if options.verbose:
    print ">>>>> Data loaded:"
    pp = pprint.PrettyPrinter(indent=4)
    pp.pprint(data)

# For example: database, lags, skip, source (this is provided in counter name)
counter_type = options.counter.split(':')[0]

if not counter_type in data:
    print ">>>>> No such counter type: %s" % (counter_type,)

counter_data_value = dict(data.get(counter_type, {})).get(options.counter)
counter_value = counter_data_value
if counter_data_value is None:
    counter_value = options.defaultvalue

if options.verbose:
    print ">>>>> Reading counter value from data: %s (defaultvalue: %s)" % (counter_data_value, options.defaultvalue)

try:
    counter_value = float(counter_value)
except:
    print "CRITICAL - Value is not a number: %s" % (counter_value,)
    sys.exit(2)

if options.cacti:
    if options.verbose:
        print ">>>>> Cacti output"
    print "value:%s" % (counter_value)
    sys.exit(0)

# Are we checking counter value or counter age?
mon_type = "value"
if options.age:
    mon_type = "age"
    cache_dir = "/tmp/redlist_counters"
    try:
        os.makedirs(cache_dir)
    except OSError:
        if not os.path.isdir(cache_dir):
            print "CRITICAL - Unable to create temporary cache dir for counter data: %s" % (cache_dir)
            sys.exit(2)
    cache_file = "%s/%s-%s.tmp" % (cache_dir, options.host, options.counter.replace(':','-'))
    t_now = int(time.time())
    value = 0.0
    if os.path.exists(cache_file):
        t_cache = int(os.path.getmtime(cache_file))
        try:
            c_counter_value = open(cache_file, 'r').read()
        except:
            print "CRITICAL - Unable to read counter cache file: %s" % (cache_file)
            sys.exit(2)
        try:
            c_counter_value = float(c_counter_value)
        except:
            print "CRITICAL - Corrupt counter cache file: %s" % (cache_file)
            sys.exit(2)
        if (c_counter_value == counter_value):
            value = float(t_now - t_cache)

    if (value == 0.0):
        try:
            fh = open(cache_file, 'w')
            fh.write("%.1f" % (counter_value))
            fh.close()
        except:
            print "CRITICAL - Unable to update counter cache file: %s" % (cache_file)
            sys.exit(2)
else:
    value = counter_value

if options.inverse:
    if options.verbose:
        print ">>>>> Comparing thresholds in inverse mode (%s must be > thresholds)" % (mon_type)
    if (value <= crit_threshold):
        print "CRITICAL - %s %s is %s (below threshold of %s)" % (options.counter, mon_type, value, crit_threshold)
        sys.exit(2)
    elif (value <= warn_threshold):
        print "WARNING - %s %s is %s (below threshold of %s)" % (options.counter, mon_type, value, warn_threshold)
        sys.exit(1)
else:
    if options.verbose:
        print ">>>>> Comparing thresholds (%s must be < thresholds)" % (mon_type)
    if (value >= crit_threshold):
        print "CRITICAL - %s %s is %s (above threshold of %s)" % (options.counter, mon_type, value, crit_threshold)
        sys.exit(2)
    elif (value >= warn_threshold):
        print "WARNING - %s %s is %s (above threshold of %s)" % (options.counter, mon_type, value, warn_threshold)
        sys.exit(1)

print "OK - %s %s is %s" % (options.counter, mon_type, value)
sys.exit(0)
