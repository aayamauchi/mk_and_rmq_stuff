#!/usr/bin/python26
#==============================================================================
# corpus_queue_log_outliers.py
#
# Compare corpus queue log sizes and report if given hostname is an outlier.
# You can specify whether to compare the current pre or post processor logs.
#
# Outliers (logs that are too small or too large compared with peers) are
# detected using two methods: inter-quartile and the z-test. Either test can
# flag a log file as an outlier.
#
# An alert is raised if the specified host's log is an outlier.
#
# 2011-04-22 jramache
#==============================================================================
from optparse import OptionParser
import socket, urllib2, os, sys
from datetime import datetime

def usage():
    print "syntax: %s -H <hostname> [-L <syslog server>] [-l <pre or post>] [-u <user>]" % (sys.argv[0])

parser = OptionParser()
parser.add_option("-H", "--hostname", dest="hostname", help="Queue hostname")
parser.add_option("-L", "--log_server", dest="syslog", default="syslog1.soma.ironport.com", help="Syslog server to retrieve log data from, default: syslog1.soma.ironport.com")
parser.add_option("-l", "--log_type", dest="logtype", default="post", help="Type of processor logs to compare: pre or post, default: post")
parser.add_option("-u", "--user", dest="user", default="nagios", help="Optional user to ssh as, default: nagios")
parser.add_option("-e", "--env", dest="env", default="prod", help="Environment, default: prod")
parser.add_option("-v", "--verbose", action="store_true", dest="verbose", default=False, help="Verbose output, default: False")
(options, args) = parser.parse_args()

if not options.hostname:
    usage()
    sys.exit(2)

if ((options.logtype != 'post') and (options.logtype != 'pre')):
    usage()
    sys.exit(2)

nagios_states = {'ok': 0, 'warning': 1, 'critical': 2, 'unknown': 3}
exit_code = nagios_states['unknown']
exit_info = "Unable to determine whether %sprocessor log file size is an outlier" % (options.logtype)

socket.setdefaulttimeout(20)

def get_hosts(**server_filters):
    base_url = "http://asdb.ironport.com/servers/list/?"
    x = []
    for filter in server_filters.iterkeys():
        x.append('%s__name__exact=%s' % (filter, server_filters[filter]))

    url = base_url + '&'.join(x)

    try:
        web_req = urllib2.urlopen(url)
    except:
        return []
    else:
        return web_req.read().split()

# Figure out what hosts to include in test group.
hosts = get_hosts(product='corpus', purpose='queue', environment=options.env)
host_count = len(hosts)

if host_count <= 0:
    print "UNKNOWN - Could not retrieve list of corpus %s queue hosts from ASDB" % (options.env)
    sys.exit(nagios_states['unknown'])

if options.hostname not in hosts:
    print "UNKNOWN - %s is not a member of %s corpus queue hosts" % (options.hostname, options.env)
    sys.exit(nagios_states['unknown'])

if options.verbose:
    print "---- retrieving %sprocessor logs from %s ----" % (options.logtype, options.syslog)

today = datetime.now().strftime("%Y%m%d")
data = []
hostdata = {}
for host in hosts:
    logsize = os.popen('/usr/bin/ssh %s "stat -f%s /logs/servers/%s/ironport/%sprocessor-%s.log 2>/dev/null"' % (options.syslog, '%z', host, options.logtype, today)).readlines()
    if (len(logsize) >= 1):
	try:
            num = int(logsize[0])
        except:
            pass
        else:
            hostdata[host] = num
            data.append(num)
    else:
        hostdata[host] = 0
        data.append(0)
data.sort()

if options.verbose:
    print
    print "---- log sizes ----"
    for host in sorted(hostdata.iterkeys()):
        print "%s:  %d" % (host, hostdata[host])

w_outliers = []
c_outliers = []

#--------------------------------------------------
# inter-quartile test
#--------------------------------------------------
if options.verbose:
    print
    print "---- performing inter-quartile test ----"

q25 = data[int(round(.25 * len(data))) - 1]
q75 = data[int(round(.75 * len(data))) - 1]
iqr = q75 - q25

# Note: the statistical standard is 1.5 for minor outlier, 3.0 for extreme outlier.
# To put this another way, a higher factor makes the monitor less sensitive.
w_factor = 10.0
c_factor = 12.0

for num in data:
    if (abs(num - q75) > (c_factor * iqr)):
        if options.verbose:
            print "---- extreme outlier found: %d ----" % (num)
        if num not in c_outliers:
            c_outliers.append(num)
    elif (abs(num - q75) > (w_factor * iqr)):
        if options.verbose:
            print "---- minor outlier found: %d ----" % (num)
        if num not in w_outliers:
            w_outliers.append(num)

#--------------------------------------------------
# z-test
#--------------------------------------------------
if options.verbose:
    print
    print "---- performing z-test ----"

def meanstdv(x):
    from math import sqrt
    n, mean, std = len(x), 0, 0
    for a in x:
        mean = mean + a
    mean = mean / float(n)
    for a in x:
        std = std + (a - mean)**2
    std = sqrt(std / float(n-1))
    return mean, std

mean, stdv = meanstdv(data)

# Note: the statistical standard is 3.0 for the z-test
w_factor = 4.0
c_factor = 5.0

for num in data:
    z = abs(num - mean) / stdv
    if (((abs(num - mean)) / stdv) > c_factor):
        if options.verbose:
            print "---- extreme outlier found: %d ----" % (num)
        if num not in c_outliers:
            c_outliers.append(num)
    elif (((abs(num - mean)) / stdv) > w_factor):
        if options.verbose:
            print "---- minor outlier found: %d ----" % (num)
        if num not in w_outliers:
            w_outliers.append(num)

#--------------------------------------------------
# Is the host we're inspecting an outlier?
#--------------------------------------------------
if options.verbose:
    print
    print "---- determining whether %s is an outlier ----" % (options.hostname)

is_outlier = False

# criticals
for outlier in c_outliers:
    if hostdata[options.hostname] == outlier:
        is_outlier = True
        if (outlier <= q25):
            description = "smaller"
        else:
            description = "larger"
        exit_code = nagios_states['critical']
        exit_info = "%sprocessor log size (%d) is %s than peers" % (options.logtype, outlier, description)

# warnings
if not is_outlier:
    for outlier in w_outliers:
        if hostdata[options.hostname] == outlier:
            is_outlier = True
            if (outlier <= q25):
                description = "smaller"
            else:
                description = "larger"
            exit_code = nagios_states['warning']
            exit_info = "%sprocessor log size (%d) is slightly %s than peers" % (options.logtype, outlier, description)

if options.verbose:
    if ((not is_outlier) and ((len(c_outliers) > 0) or (len(w_outliers) > 0))):
        print "     it is not, but another host is an outlier"
    elif (not is_outlier):
        print "     it is not, in fact no outliers were found at all"
    else:
        print "     yes, it is an outlier!"
    print

if not is_outlier:
    exit_code = nagios_states['ok']
    exit_info = "%sprocessor log file size is similar to peers" % (options.logtype)

exit_state = 'unknown'
for s in nagios_states.keys():
    if nagios_states[s] == exit_code:
        exit_state = s
print "%s - %s" % (exit_state.upper(), exit_info)
for host in sorted(hostdata.iterkeys()):
    if options.hostname == host:
        print "%s:  %d [host that was checked]" % (host, hostdata[host])
    else:
        print "%s:  %d" % (host, hostdata[host])

if options.verbose:
    print
    print "---- exiting with exit code %d ----" % (exit_code)

sys.exit(exit_code)
