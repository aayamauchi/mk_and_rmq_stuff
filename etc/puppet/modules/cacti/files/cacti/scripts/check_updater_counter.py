#!/usr/bin/python26
#========================================================================
# check_updater_counter.py
#
# Updater 2.0 counter monitor.
# http://eng.ironport.com/docs/is/updater/monitoring.rst#counters
#
# Retrieves counters in json format from http://host:port/counters.
# Operates in cacti mode with --cacti, in which case thresholds are
# ignored and the value of the counter is returned as value:float.
# Otherwise it assumes nagios operation and requires valid thresholds.
# 
# 2012-09-19 jramache
#========================================================================
import sys, os, simplejson, urllib2, pprint, time
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
                        default=8080, help="Http port where counters can be retrieved")
parser.add_option("--counter", type="string", dest="counter",
                        default=None, help="Counter to check")
parser.add_option("--warning", type="float", dest="warning",
                        default=None, help="Warning threshold for counter")
parser.add_option("--critical", type="float", dest="critical",
                        default=None, help="Critical threshold for counter")
parser.add_option("--inverse", dest="inverse", action="store_true",
                        default=False, help="Inverse threshold comparisons")
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

def get_cache():
    # return json or None
    json = None
    try:
        cache_fh = open(cachefile, "rb")
    except:
        if options.verbose:
            print ">>>>> Unable to open cache file for reading"
    else:
        try:
            data = simplejson.load(cache_fh)
        except:
            if options.verbose:
                print ">>>>> Unable to parse json from cache file"
        else:
            json = data
        cache_fh.close()

    return json

def get_server():
    # return valid json or None
    json = None
    url = "http://%s:%d/counters" % (options.host, options.port)
    req = urllib2.Request(url)
    try:
        if options.verbose:
            print ">>>>> Opening connection to %s" % (url)
        http_connection = urllib2.urlopen(url)
        code = getcode(http_connection)
    except Exception, e:
        if options.verbose:
            print "CRITICAL - Problem accessing counter URL %s : %s" % (url, e)
    else:
        if code >= 400:
            if options.verbose:
                print "Problem accessing counter URL %s, Server returned HTTP CODE %d" % (url, code)
        else:
            try:
                if options.verbose:
                    print ">>>>> Loading json from http connection"
                data = simplejson.load(http_connection)
            except:
                if options.verbose:
                    print "Invalid data returned from server (unable to parse json)"
            else:
                json = data
                if options.verbose:
                    print ">>>>> json data loaded:"
                    pp = pprint.PrettyPrinter(indent=4)
                    pp.pprint(json)

    return json

def update_cache(json):
    # is there a lock file? (or is it older than expire seconds?)
    open_lock = True
    t_now = time.time()
    if os.path.exists(lockfile):
        t_lock = os.path.getmtime(lockfile)
        t_age = t_now - t_lock
        if t_age < lock_expire:
            open_lock = False
    if open_lock:
        # (re)create lock
        try:
            lock_fh = open(lockfile, "wb")
            lock_fh.write("%d" % (time.time()))
            lock_fh.close()
        except:
            if options.verbose:
                print "Unable to create lock file"
        else:
            # update cache file
            try:
                cache_fh = open(cachefile, "wb")
            except:
                if options.verbose:
                    print "Unable to open cache file for writing"
            else:
                try:
                    cache_fh.write("%s" % (simplejson.dumps(json)))
                except:
                    if options.verbose:
                        print "Unable to write to cache file"
                cache_fh.close()
            # delete the lock
            try:
                os.remove(lockfile)
            except:
                if options.verbose:
                    print "Unable to delete lock file"

#
# do we have a fresh cache?
#
# keep separate cache files for cacti and nagios:
# allows for unique user perms (apache and nagios users) and freshness intervals
if options.cacti:
    cachefile = "/tmp/cache_c_%s_counters" % (options.host)
    t_expire = 120
else:
    cachefile = "/tmp/cache_n_%s_counters" % (options.host)
    t_expire = 60
lockfile = cachefile + ".lock"
lock_expire = t_expire
if os.path.exists(cachefile):
    # cache exists. if fresh, read it. otherwise, update it.
    t_now = time.time()
    t_cache = os.path.getmtime(cachefile)
    t_age = t_now - t_cache
    if t_age < t_expire:
        # fresh cache
        if options.verbose:
            print ">>>>> Attempting to read from fresh cache"
        json = get_cache()
        if json is None:
           # corrupt cache, try to refresh it with new data from server
           json = get_server()
           if json is not None:
               update_cache(json)
    else:
        # cache has expired, so retrieve counters from server and refresh cache
        if options.verbose:
            print ">>>>> Stale cache, will hit server instead"
        json = get_server()
        if json is not None:
            update_cache(json)
else:
    # there is no cache file at all, query server and create cache
    json = get_server()
    if json is not None:
        update_cache(json)

if json is None:
    print "CRITICAL - Unable to retrieve counters from cache or server"
    sys.exit(2)

if options.counter not in json:
    print "CRITICAL - %s was not found in counters" % (options.counter)
    sys.exit(2)

value = None
try:
    if options.verbose:
        print ">>>>> Reading value from data"
    value = float(json[options.counter])
except:
    print "CRITICAL - Value returned from server is not a number: %s" % (json[options.counter])
    sys.exit(2)

if options.cacti:
    if options.verbose:
        print ">>>>> Cacti output"
    print "value:%s" % (value)
    sys.exit(0)

if options.inverse:
    if options.verbose:
        print ">>>>> Comparing thresholds in inverse mode (value must be > thresholds)"
    if (value <= crit_threshold):
        print "CRITICAL - %s is %s (below threshold of %s)" % (options.counter, value, crit_threshold)
        sys.exit(2)
    elif (value <= warn_threshold):
        print "WARNING - %s is %s (below threshold of %s)" % (options.counter, value, warn_threshold)
        sys.exit(1)
else:
    if options.verbose:
        print ">>>>> Comparing thresholds (value must be < thresholds)"
    if (value >= crit_threshold):
        print "CRITICAL - %s is %s (above threshold of %s)" % (options.counter, value, crit_threshold)
        sys.exit(2)
    elif (value >= warn_threshold):
        print "WARNING - %s is %s (above threshold of %s)" % (options.counter, value, warn_threshold)
        sys.exit(1)

print "OK - %s is %s" % (options.counter, value)
sys.exit(0)
