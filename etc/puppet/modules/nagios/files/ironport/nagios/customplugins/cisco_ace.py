#!/usr/bin/python26 -u
"""Script for pulling serverfarm statistics out of a Cisco ACE device
via ssh.  Output is suitable for Nagios or Cacti plugins.

Mike Lindsey <miklinds@cisco.com>  1/4/2010
"""

# -*- coding: ascii -*-

import warnings
warnings.filterwarnings('ignore', '.*', DeprecationWarning)
import paramiko
import sys
import os
import shutil
import string
import socket
import time
import simplejson
import sets
import fcntl
import tempfile

print "Disabled at NetOps request, until they can upgrade the ACEs"
sys.exit(0)

from optparse import OptionParser

def funcname():
    """so we don't have to keep doing this over and over again."""
    return sys._getframe(1).f_code.co_name

def init():
    """collect option information, display help text if needed, set up debugging"""
    usage = "usage: %prog --device [device] --username [user] --password [pw] [options]\n"
    usage += "example: %prog -d ace-core-a.soma.ironport.com -l '-a,-b' -C -ops -u mon1 -p pw --replace '-a'"
    parser = OptionParser(usage=usage)
    parser.add_option("-d", "--device", type="string", dest="device",
                            help="hostname to query.")
    parser.add_option("-l", "--list", type="string", dest="devicelist",
                            help="Optional CSV device list to iterate through.\
    Inserted into device name, before first dot.\
    When multiples are queried, numeric stats are summed.  Text stats are from first device.")
    parser.add_option("-r", "--replace", type="string", dest="replace",
                            help="Match passed string, and replace with --list item, instead of a blind insert.")
    parser.add_option("-C", "--context", type="string", dest="context",
                            help="Optional device context string.\
    Inserted into device name, before first dot, after iterative device list.")
    parser.add_option("-s", "--serverfarm", type="string", dest="serverfarm",
                            help="serverfarm to query, blank or partial matches return a list.")
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="only print for this host, blank lists hosts, partial matches acceptable")
    parser.add_option("-u", "--username", type="string", dest="username",
                            help="username to login with, file or string.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="password to login with, file or string.")
    parser.add_option("-P", "--port", type="int", dest="port",
                            help="port to connect on.  default=22", default=22)
    parser.add_option("-w", "--warning", type="int", dest="warning",
                            default=1,
                            help="""How many servers can fail before a warning state is reached.
If not passed, any failures will trigger a warning state.""")
    parser.add_option("-c", "--critical", type="int", dest="critical",
                            help="""How many servers can fail before a critical state is reached.
If not passed, critical is triggered at 2 failures, unless
pool size is lt 3, then critical is triggered at 1 failed server.
If pool size is 1, critical is triggered at 1 failed server.""")
    parser.add_option("--cacti", action="store_true", dest="cacti",
                            default=False, help="Output cacti stats instead of nagios data.")
    parser.add_option("--cache", type="int", dest="cache",
                            help="How many seconds to retain and reuse cache. default: 60",
                            default=120)
    parser.add_option("--grace", type="int", dest="grace",
                            help="""Percentage of vip that can be Out-of-service, before raising
alert.  Rounded down, will not allow all servers to be OOS, without raising alert.
default=50%""", default=50) 
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    error = 0
    if not options.device:
        sys.stderr.write("Missing --device\n")
        error += 1
    if not options.username:
	sys.stderr.write("Missing --username\n")
        error += 1 
    if not options.password:
	sys.stderr.write("Missing --password\n")
        error += 1
    if options.replace and options.device and options.replace not in options.device:
        sys.stderr.write("--replace passed, but '%s' not in --device '%s'\n" % \
                (options.replace, options.device))
        error += 1
    if error:
        parser.print_help()
        sys.exit(3)
    try:
        username = open(options.username).read()
    except:
        if options.verbose: print "--username should be a file"
    else:
        options.username = username
    try:
        password = open(options.password).read()
    except:
        if options.verbose: print "--password should be a file"
    else:
        options.password = password
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return options

def connect(hostname):
    """Connect and return a SSHClient object"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy()) 

    if options.verbose:
        print "About to attempt connection to %s" % (hostname)
    try:
        client.connect(hostname=hostname, username=options.username, \
                password=options.password, port=options.port)
    except paramiko.BadAuthenticationType:
        error_str += "BadAuthenticationType Failure for %s\n" % (device)
        raise
    except paramiko.AuthenticationException:
        error_str += "Authentication Failure '%s' for %s\n" % (sys.exc_info()[1], device)
        raise
    except socket.gaierror:
        error_str += "'%s' error for %s\n" % (sys.exc_info()[1][1], device)
        raise
    except socket.error:
        error_str += "Socket error for %s\n" % (device)
        raise
    except:
        error_str += "Connection Error for %s\n" % (device)
        error_str += "%s\n" % (str(sys.exc_info()))
        raise

    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return client

def get_stats(device):
    """Hit a device and grab all the stats"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    client = connect(device)
    serverfarms = get_serverfarms(client)
    stats = {}
    for serverfarm in serverfarms:
        stats[serverfarm] = inspect_serverfarm(client, serverfarm)
    client.close()
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return stats

def get_serverfarms(client):
    """Get and return a list of serverfarms"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    serverfarms = run(client, 'show serverfarm\n')
    serverfarm_list = []

    for line in serverfarms.split('\n'):
        line = line.lstrip()
        if line.startswith('+') or line.startswith('HOST') or \
                line.startswith('serverfarm') or line.startswith('NOTE') or \
                not line:
            continue
        else:
            serverfarm_list.append(line)

    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return serverfarm_list

def inspect_serverfarm(client, serverfarm):
    """Get serverfarm stats and return dictionary"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    total = 0
    rserver = ''
    serverfarm_dict = {}
    stats_dict = {
            'total'     : 0,
            'failures'  : 0,
            'totalcon'  : 0,
            'currentcon'        : 0,
            'failedcon' : 0,
            'hosttypes' : []
            }
    for line in run(client, "show serverfarm %s" % (serverfarm)).split('\n'):
        line = line.lstrip()
        if line.startswith('total rservers'):
            total = int(line.split()[-1])
        elif line.startswith('rserver:'):
            rserver = line.split()[-1]
        elif rserver:
            line = line.split()
            serverfarm_dict[rserver] = {
                    'ip'        : line[0],
                    'weight'    : int(line[1]),
                    'state'     : line[2],
                    'current'   : int(line[3]),
                    'total'     : int(line[4]),
                    'failures'  : int(line[5]),
                    }
            stats_dict['total'] += 1
            if line[2] != 'OPERATIONAL':
                stats_dict['failures']  += 1
            stats_dict['currentcon']    += int(line[3])
            stats_dict['totalcon']      += int(line[4])
            stats_dict['failedcon']     += int(line[5])
            stats_dict['hosttypes'].append((rserver,line[2]))
            rserver = ''

    if options.verbose:
        print "About to return serverfarm_dict, stats_dict:"
        print serverfarm_dict, stats_dict
        sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return serverfarm_dict, stats_dict

def run(client, cmd):
    """Open channel on transport, run command, capture output and return"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: print 'DEBUG: Running cmd:', cmd
    #chan.setblocking(0)
    stdin, stdout, stderr = client.exec_command("%s" % (cmd))
    
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return stdout.read()


exitcode = 3
options = init()

logfile = '/tmp/cisco_ace-%s-paramiko.log' % (options.serverfarm)
if os.path.exists(logfile):
    try:
        os.remove(logfile)
    except:
        if options.verbose:
            print "Unable to purge logfile %s" % (logfile)
try:
    paramiko.util.log_to_file(logfile)
except:
    if options.verbose:
        print "Unable to open logfile %s" % (logfile)
    try:
        paramiko.util.log_to_file('/dev/null')
    except:
        print "Also unable to redirect logging to /dev/null"
else:
    try:
        os.chmod(logfile, 0666)
    except:
        if options.verbose:
            print "Unable to chmod logfile %s" % (logfile)

error_str = ''
try:
    devices = options.devicelist.split(',')
except:
    devices = ['']
devicelist = []
faillist = []
stats = {}

if options.verbose:
    print "Running with devicelist: %s" % (str(devices))
device_done = False
for device in devices:
    head = options.device.split('.')[0]
    if not options.context:
        options.context = ''
    tail = str(options.device)[len(head)::]
    if options.replace:
        head = head.replace(options.replace, device)
        device = '%s%s%s' % (head, options.context, tail)
    else:
        device = '%s%s%s%s' % (head, device, options.context, tail)
    if options.verbose:
        print "Beginning run for device %s" % (device)
    cache_file = '/tmp/%s_%s' % (os.path.basename(sys.argv[0]), device)
    # Does the cache file exist, and is it new enough?
    # if not, fork and let a child refresh the cache.
    # grab old cache while it's updating.
    lockfile = '/tmp/%s_%s.lock' % (os.path.basename(sys.argv[0]), device)
    pid = 1
    if (not os.path.exists(cache_file)) or \
            (os.stat(cache_file)[8] < (time.time() - options.cache)):
        if options.verbose:
            print "Stale cache, forking."
        pid = os.fork()
    if not pid:
        lockfd = open(lockfile, 'w')
        try:
            os.chmod(lockfile, 0666)
        except:
            if options.verbose:
                print "Child unable to chmod lockfile, probably not nagios user."
        try:
            fcntl.lockf(lockfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except:
            if options.verbose:
                print "Child can't get '%s' lock, exiting." % (lockfile)
        else:
            if options.verbose:
                print "Child got %s lock, grabbing stats." % (lockfile)
            try:
                stats[device] = get_stats(device)
            except:
                fcntl.lockf(lockfd, fcntl.LOCK_UN)
            else:
                if options.verbose:
                    print "Child got stats for %s" % (device)
                try:
                    (cache_fd, temp_file) = tempfile.mkstemp()
                except:
                    if options.verbose:
                        print "Child unable to make temp file for %s\n" % (device)
                else:
                    if options.verbose:
                        print "Made temp file for cache."
                    cache_fd = os.fdopen(cache_fd, 'w')
                    stats[device] = simplejson.dumps(stats[device])
                    cache_fd.write(stats[device])
                    cache_fd.close()
                    try:
                        os.rename(temp_file, cache_file)
                    except:
                        if options.verbose:
                            print "Child unable to refresh cache for %s from tempfile %s\n" % \
                                (device, temp_file)
                    else:
                        if options.verbose:
                            print "Moved %s to %s" % (temp_file, cache_file)
                try:
                    os.chmod(cache_file, 0666)
                except:
                    if options.verbose:
                        print "Child unable to chmod cache_file."
                fcntl.lockf(lockfd, fcntl.LOCK_UN)
            lockfd.close()
            try:
                os.remove(lockfile)
            except:
                if options.verbose:
                    print "Unable to remove lockfile."
        # Child done, exit.
        sys.exit(0)
    else:
        if os.path.exists(cache_file) and os.stat(cache_file)[8] < (time.time() - (10 * options.cache)):
            error_str += "Cache excessively stale for %s\n" % (cache_file)
        # Grab the cache.
        if os.path.exists(cache_file):
            if options.verbose:
                print "Reading cache file '%s'\n" % (cache_file)
            try:
                stats[device] = open(cache_file).read()
            except:
                error_str += "Unable to open cache file '%s'\n" % (cache_file)
                faillist.append(device)
            else:
                try:
                    stats[device] = simplejson.loads(stats[device])
                except:
                    error_str += "Unable to read JSON from cahe file '%s'\n" % (cache_file)
                    faillist.append(device)
        else:
            error_str += "Missing cache for %s\n" % (device)
            faillist.append(device)
        
    devicelist.append(device)

if (len(devicelist) == len(faillist)):
    print "Tried, but couldn't find stats or active devices.\n%s" % (str(faillist))
    if error_str:
        print error_str,
    try:
        shutil.copy(logfile, '%s.3' % (logfile))
    except:
        if options.verbose:
            print "Unable to copy logfile"
    sys.exit(3)

serverfarms = []
for device in stats:
    serverfarms = sets.Set(list(serverfarms) + stats[device].keys())

if options.verbose:
    print "Device list:\n%s" % (devicelist)
if options.verbose:
    print "Serverfarm list:\n%s" % (serverfarms)

if options.serverfarm and options.serverfarm in serverfarms:
    serverfarm_dict = {}
    serverfarmsum_dict = {}
    stats_dict = {}
    statssum_dict = {}
    for device in stats:
        serverfarm_dict[device] = {}
        stats_dict[device] = {}
        serverfarm_dict[device] = stats[device][options.serverfarm][0]
        stats_dict[device] = stats[device][options.serverfarm][1]
        servers = serverfarm_dict[device].keys()
        servers.sort()
    for device in stats:
        for key in stats_dict[device].keys():
            if statssum_dict.has_key(key):
                statssum_dict[key] += stats_dict[device][key]
            else:
                statssum_dict[key] = stats_dict[device][key]
        for key in serverfarm_dict[device].keys():
            if not serverfarmsum_dict.has_key(key):
                serverfarmsum_dict[key] = {}
            for subkey in serverfarm_dict[device][key].keys():
                if subkey == 'state':
                    if serverfarmsum_dict.has_key(serverfarm_dict[device][key][subkey]):
                        serverfarmsum_dict[serverfarm_dict[device][key]['state']] += 1
                    else:
                        serverfarmsum_dict[serverfarm_dict[device][key]['state']] = 1
                if serverfarmsum_dict[key].has_key(subkey) and \
                        type(serverfarm_dict[device][key][subkey]) == type(1):
                    serverfarmsum_dict[key][subkey] += serverfarm_dict[device][key][subkey]
                elif serverfarmsum_dict[key].has_key(subkey) and \
                        (type(serverfarm_dict[device][key][subkey]) == type(u'') or \
                        type(serverfarm_dict[device][key][subkey]) == type('')):
                    serverfarmsum_dict[key][subkey] += '/%s' % \
                            (serverfarm_dict[device][key][subkey])
                elif not serverfarmsum_dict[key].has_key(subkey):
                    # 1st device will generally be the active device.
                    serverfarmsum_dict[key][subkey] = serverfarm_dict[device][key][subkey]
                else:
                    if options.verbose:
                        print "Fell through sum_dict construction."
                        print "serverfarmsum_dict[key][subkey]:\n  %s" % \
                                (serverfarmsum_dict[key][subkey])
                        print "serverfarm_dict[device][key][subkey]\n  %s" % \
                                (serverfarm_dict[device][key][subkey])
                        print "type(serverfarm_dict[device][key][subkey])\n  %s" % \
                                (type(serverfarm_dict[device][key][subkey]))
    # So we print the right values, and can track partial failures.
    if options.verbose:
        print "statssum_dict:\n%s" % (statssum_dict)
        print "serverfarmsum_dict:\n%s" % (serverfarmsum_dict)
    statssum_dict['total'] = statssum_dict['total'] / len(stats)
    statssum_dict['failures'] = statssum_dict['failures'] / float(len(stats))
    if serverfarmsum_dict.has_key('OUTOFSERVICE'):
        statssum_dict['oos'] = serverfarmsum_dict['OUTOFSERVICE'] / float(len(stats))
    else:
        statssum_dict['oos'] = 0
    if statssum_dict['failures'] == int(statssum_dict['failures']):
        statssum_dict['failures'] = int(statssum_dict['failures'])
    if not options.host:
        if not options.cacti:
            if not options.critical:
                if statssum_dict['total'] > 2: 
                    options.critical = 2
                else:
                    options.critical = 1
            print "%s/%s servers operational for '%s' on %s" % \
                    (statssum_dict['total'] - statssum_dict['failures'], statssum_dict['total'],
                    options.serverfarm, options.device.replace(options.replace,"[%s]" % \
                            options.devicelist))
            # int casting the grace limit rounds down for safety.
            if statssum_dict['oos'] <= int(statssum_dict['total'] * (options.grace * .01)) and \
                    statssum_dict['failures'] < statssum_dict['total']:
                # if less than all servers have failed, and less than options.grace are
                # out of service, remove oos from failure metric before checking thresholds,
                # but after display.
                statssum_dict['failures'] -= statssum_dict['oos']
                if options.verbose:
                    print "Reducing failures(%s) metric by oos (%s)" % \
                            (statssum_dict['failures'], statssum_dict['oos'])
            if statssum_dict['failures'] >= options.warning:
                exitcode = 1
            if statssum_dict['failures'] >= options.critical:
                exitcode = 2
            if exitcode == 3:
                exitcode = 0
            for server in servers:
                print "%s in state %s" % (server, serverfarmsum_dict[server]['state'])
        else:
            print "total:%s failures:%s currentcon:%s totalcon:%s failedcon:%s" % \
                    (statssum_dict['total'], statssum_dict['failures'], \
                    statssum_dict['currentcon'], statssum_dict['totalcon'], \
                    statssum_dict['failedcon'])
    elif options.host is '':
        for server in servers:
            print server
    else:
        if options.host in servers:
            if not options.cacti:
                print "%s is %s" % (options.host, \
                        serverfarmsum_dict[options.host]['state']),
                if serverfarmsum_dict[options.host]['state'] == 'OPERATIONAL':
                    exitcode = 0
                else:
                    exitcode = 2
            else:
                print "currentcon:%s totalcon:%s failedcon:%s" % \
                        (serverfarmsum_dict[options.host]['current'],
                        serverfarmsum_dict[options.host]['total'],
                        serverfarmsum_dict[options.host]['failures'])
                
        else:
            printed = 0
            for server in servers:
                if server.startswith(options.host):
                    if not options.cacti:
                        print "%s is %s" % (server, \
                                serverfarmsum_dict[server]['state']),
                        printed = 1
                        if serverfarmsum_dict[server]['state'] == 'OPERATIONAL':
                            exitcode = 0
                        else:
                            exitcode = 2
                        break
                    else:
                        print "currentcon:%s totalcon:%s failedcon:%s" % \
                                (serverfarmsum_dict[server]['current'],
                                serverfarmsum_dict[server]['total'],
                                serverfarmsum_dict[server]['failures'])
                        printed = 1
                        break
            if not printed:
                print "%s not found in serverfarm %s" % (options.host, options.serverfarm)
                for server in servers:
                    print server
elif options.serverfarm:
    printed = 0
    for serverfarm in serverfarms:
        if serverfarm.startswith(options.serverfarm):
            printed = 1
            print serverfarm
    if not printed:
        print "Serverfarm %s not found in serverfarm list." % (options.serverfarm)
else:
    for serverfarm in serverfarms:
        print serverfarm

try:
    shutil.copy(logfile, '%s.%s' % (logfile, exitcode))
except:
    if options.verbose:
        print "Unable to copy log file."
if error_str:
    print error_str,
    if exitcode == 0:
        exitcode = 1
if faillist and len(faillist):
    print "Device failure list: %s" % (str(faillist))
sys.exit(exitcode)
