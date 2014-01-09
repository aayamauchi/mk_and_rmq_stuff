#!/usr/bin/env python26

# Ticket: https://jira.sco.cisco.com/browse/MONOPS-1734
# Author: Bogdan Berezovyi <bberezov@cisco.com>

import dns.resolver
import optparse
import MySQLdb
import MySQLdb.cursors
import sys
import traceback
import time
import re
import os
import json
from subprocess import Popen, PIPE


def hex_to_ip(dec):
    hexip = hex(dec).lstrip('0x')
    n = 2
    hexip = [hexip[i:i+n] for i in range(0, len(hexip), n)]
    ip = [str(int(i, 16)) for i in hexip]
    return ".".join(ip)


def match_ip_to_name(lst, ip):
    for row in lst:
        if row['ip_4'] == ip:
            return row['description']


def get_external_ips(user,dns,file):
    if opt.verbose:
        print "Getting list of external ip's"
    command = 'grep ^bl.*A %s' % file
    out = Popen(['ssh', '%s@%s' % (user, dns), '%s' % command], stdout=PIPE)
    data = out.communicate()

    # Sanitizing output from remote command
    data = "".join([item for item in data if item])
    data = data.strip('\t\n\r')

    # Extracting Ip's from received data
    ip = re.compile('\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
    return ip.findall(data)

def file_exists(file):
	if (os.path.exists(file)):
		return True
	else:
		print "File %s does not exist" % file
		return False

def write_to_file(file,data):
    try:
        with open(file,'w') as f:
		    f.write(json.dumps(data))
    except (IOError, OSError, Faillure) as e:
        print "Error writing file %s" % file
        sys.exit(EXIT_CRIT)


def read_from_file(file):
    try:
        with open(file, 'r') as f:
            data = f.read()
    except (IOError, OSError, Faillure) as e:
        print "Error reading file %s" % file
        sys.exit(EXIT_CRIT)

    if len(data) == 0:
        return {}
    else:
        return json.loads(data)

def merge_dicts(dict1,dict2):
    tmp = {}
    #Leaving only those keys that are in both dictionaries
    for k,v in dict2.items():
        if k in dict1:
            tmp[k] = v
    #Adding new keys from dict1 to dict2
    for k,v in dict1.items():
        if k not in dict2:
            tmp[k] = v
    return tmp

def check_timeouts(timeouts,statfile):
    if not file_exists(statfile):
		print "writing file"
		write_to_file(statfile,timeouts)
		return timeouts
    timeouts_from_file = read_from_file(statfile)
    if opt.verbose:
        print "Timeout servers: %s" % timeouts
        print "Timeout servers from file: %s" % timeouts_from_file
    merged_timeouts = merge_dicts(timeouts, timeouts_from_file)
    if opt.verbose:
        print "Writing final timeout servers list to file: %s" % merged_timeouts
    write_to_file(statfile,merged_timeouts)
    return merged_timeouts



USAGE = """
%s -H <host> -u <user> -p <password> -d <db> -T <table>
-s <dnsserver> -f <zonefile> -c <critical> -w <warning>

host       - Database host.
user       - Database user.
password   - Database password.
db         - Database name containing the target table.
table      - Database table, default = data_sources.
dnsserver  - Address of production dns server.
zonefile   - Path to zonefile with list of external dns servers
critical   - Number of seconds for mtime to rise critical.
warning    - Number of seconds for mtime to rise warning.
ctimeout   - Number of days server has to be in constant timeout to raise critical
""" % (sys.argv[0])


optparser = optparse.OptionParser(usage=USAGE)
optparser.add_option('-H', '--host', dest='host', default=None,
                     action='store')
optparser.add_option('-u', '--user', dest='user', default='nagios',
                     action='store')
optparser.add_option('-p', '--password', dest='password', default=None,
                     action='store')
optparser.add_option('-D', '--db', dest='db', action='store')
optparser.add_option('-T', '--table', dest='table', action='store',
                     default='data_sources')
optparser.add_option('-s', '--dnsserver', dest='pdns', action='store')
optparser.add_option('-f', '--file', dest='zfile', action='store')
optparser.add_option('-v', '--verbose', dest='verbose', action='store_true',
                     default=False)
optparser.add_option('-c', '--critical', dest='critical', default=None,
                     action='store', type="int")
optparser.add_option('-w', '--warning', dest='warning', default=None,
                     action='store', type="int")
optparser.add_option('-C', '--ctimeout', dest='ctimeout', default=3,
                     action='store', type="int")

try:
    (opt, args) = optparser.parse_args()
except optparse.OptParseError, err:
    print err
    sys.exit(EXIT_CRIT)

if not (opt.host and opt.password and opt.critical and
        opt.db and opt.pdns and opt.zfile):
    print USAGE
    sys.exit(EXIT_CRIT)

EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

critical = opt.critical
warning = opt.warning
ctimeout = opt.ctimeout
now = int(time.time())
query = "SELECT description,ip_4 FROM %s;" % opt.table
check_record = 'bl.spamcop.net'
statfile = '/tmp/spamcop_stale_dns_timeouts.tmp'
user = opt.user
pdns = opt.pdns
zfile = opt.zfile

timeouts = {}
criticals = []
warnings = []

try:
    conn = MySQLdb.connect(user=opt.user, passwd=opt.password,
                           db=opt.db, host=opt.host,
                           cursorclass=MySQLdb.cursors.DictCursor)
    cursor = conn.cursor()
except MySQLdb.Error:
    traceback.print_exc()
    sys.exit(EXIT_CRIT)

try:
    cursor.execute(query)
except MySQLdb.Error:
    print "Error cant execute query"
    sys.exit(EXIT_UNK)

rows = cursor.fetchall()

# Removing disabled DNS servers from list
rows = [row for row in rows
        if row['description'].find('disabled') == int('-1')]

# Converting ip's from hex to default format
for row in rows:
    ip = hex_to_ip(int(row['ip_4']))
    row['ip_4'] = ip

# Getting list of server IP's
ips = [row['ip_4'] for row in rows]

# Getting external IP's from remote dns server
external = get_external_ips(user,pdns,zfile)

if len(external) == 0:
    print "CRITICAL: No external DNS servers IP's found"
    sys.exit(EXIT_CRIT)

# We only need IPs that are in two lists
match = list(set(ips) & set(external))

# Dict to store Names (ips) of the servers
# with corresponding timestamps in SOA records
tss = {}

# Getting soa record for each IP in the final list
resolver = dns.resolver.Resolver()
for ip in match:
    if opt.verbose:
        print "Getting SOA record from ip - %s" % ip
    # Setting dns which we will query
    resolver.nameservers = [ip]
    dns_name = match_ip_to_name(rows, ip)
    server = dns_name + ' (' + ip + ')'
    try:
        for rdata in resolver.query(check_record, 'soa'):
            tss[server] = (rdata.to_text().split(' ')[2])
    except dns.exception.Timeout:
        timeouts[server] = now

#There is something wrong with infrastructure when there are more
#servers to timeout than respond.
if len(timeouts) > len(tss):
    criticals.append("CRITICAL More then half servers timeout")

#Checking timeouts against state file.
timeouts_dict = check_timeouts(timeouts,statfile)

#Checking how long the servers in timeout dict have been in this state
for server, timestamp in timeouts_dict.iteritems():
    time_in_state = (now - int(timestamp))/86400
    date_in_state = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(timestamp))
    if opt.verbose:
        print "Server %s has timedout since %s (critical: %s days)" % (server, date_in_state, ctimeout)
    if time_in_state > ctimeout:
        criticals.insert(0,"Server %s has timedout for %s days (critical: %s)"
                        % (server, time_in_state, ctimeout))

# Comparing timestamps to thresholds
for server, timestamp in tss.iteritems():
    soa_diff = now - int(timestamp)
    if timestamp == '0':
        timeouts[server] = now
    if soa_diff > critical:
        criticals.append("Server %s has soa timestamp: %s sec (critical: %s)"
                        % (server, soa_diff, critical))
    elif soa_diff > warning:
        warnings.append("Server %s has soa timestamp: %s sec (warning: %s)"
                        % (server, soa_diff, warning))

if criticals:
    print "CRITICAL - on %s servers" % (len(criticals))
    print ('\n').join(criticals)
    sys.exit(EXIT_CRIT)
elif warnings:
    print "WARNING - on %s servers" % (len(criticals))
    print ('\n').join(warnings)
    sys.exit(EXIT_WARN)
else:
    print "OK"
    sys.exit(EXIT_OK)
