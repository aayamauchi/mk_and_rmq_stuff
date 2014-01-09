#!/usr/bin/python26 -u
"""Script for pulling WSA updater versions from a wsa
via ssh.  Output is suitable for Nagios.

Mike Lindsey <miklinds@cisco.com>  9/3/2010
"""
 
# -*- coding: ascii -*-

import warnings
warnings.filterwarnings('ignore', '.*', DeprecationWarning)
import paramiko
import sys
import os
import string
import time
import socket

from optparse import OptionParser

def funcname():
    """so we don't have to keep doing this over and over again."""
    return sys._getframe(1).f_code.co_name

def init():
    """collect option information, display help text if needed, set up debugging"""
    usage = "usage: %prog -d [device] -s '[string]' -w [warning] -c [critical]\n"
    parser = OptionParser(usage=usage)
    parser.add_option("-d", "--device", type="string", dest="device",
                            help="hostname to query.")
    parser.add_option("-u", "--username", type="string", dest="username",
                            help="username to login with, file or string.",
                            default="guest")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="password to login with, file or string.",
                            default="ironport")
    parser.add_option("-P", "--port", type="int", dest="port",
                            help="port to connect on.  default=22", default=22)
    parser.add_option("-w", "--warning", type="int", dest="warning",
                            help="Warning threshold in seconds.")
    parser.add_option("-c", "--critical", type="int", dest="critical",
                            help="Critical threshold in seconds.")
    parser.add_option("-s", "--string", type="string", dest="string",
                            help="Updater string to check.")
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
    if not options.warning:
        sys.stderr.write("Missing --warning\n")
        error += 1
    if not options.critical:
        sys.stderr.write("Missing --critical\n")
        error += 1
    if options.warning and options.critical and options.warning > options.critical:
        sys.stderr.write("Warning must be less than critical\n")
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

    client.connect(hostname=hostname, username=options.username, \
            password=options.password, port=options.port)

    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return client

def run(client, cmd):
    """Open channel on transport, run command, capture output and return"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: print 'DEBUG: Running cmd:', cmd
    #chan.setblocking(0)
    stdin, stdout, stderr = client.exec_command("%s" % (cmd))
    
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return stdout.readlines()


if __name__ == '__main__':
    exitcode = 3
    options = init()

    #paramiko.util.log_to_file('paramiko.log')
    error_str = ''
    try:
        client = connect(options.device)
    except paramiko.BadAuthenticationType:
        error_str += "BadAuthenticationType Failure for %s\n" % (options.device)
    except paramiko.AuthenticationException:
        error_str += "Authentication Failure '%s' for %s\n" % (sys.exc_info()[1], options.device)
    except socket.gaierror:
        error_str += "'%s' error for %s\n" % (sys.exc_info()[1][1], options.device)
    except socket.error:
        error_str += "Socket error for %s\n" % (options.device)
    except:
        error_str += "Connection Error for %s\n" % (options.device)
        error_str += "%s\n" % ([sys.exc_info()])

    if error_str:
        print error_str,
    else:
        updater_ts = {}
        preline = None
        for line in run(client, 'version'):
            line = line.strip()
            # The terminal is getting set to 80 chars wide, causing line wrap
            # issues in the output.  We can set the terminal to wider, but
            # it requires building the ssh connection by hand, instead of just
            # using SSHClient.  Instead of doing that the hard way, we're just
            # going to rebuild the wrapped lines in this clunky but functional
            # way.  Enjoy!
            if len(line) > 60 and line[-1] != ')':
                preline = line
                continue
            if preline is not None:
                line = preline + ' ' + line
                preline = None
            if options.verbose:
                print '%d %s' % (len(line), line),
            if ':' in line and '(' in line:
                (updater, ts) = line.split(':', 1)
                updater_ts[updater] = ts.strip()
                if options.verbose:
                    print "updater '%s' is '%s'" % (updater, ts.strip())

        if options.string in updater_ts.keys():
            try:
                datestr = updater_ts[options.string].split('(')[1].split(')')[0]
            except:
                exitcode = 3
                print "Cannot extract timestamp string."
            else:
                try:
                    delta = time.time() - time.mktime(time.strptime(datestr))
                except:
                    exitcode = 3
                    print "Unable to parse timestamp '%s'" % (datestr)
                else:
                    if delta >= options.critical:
                        exitcode = 2
                        print "%s is %ds old (gt %d)" % (options.string, \
                                delta, options.critical)
                    elif delta >= options.warning:
                        exitcode = 1
                        print "%s is %ds old (gt %d, lt %d)" % (options.string, \
                                delta, options.warning, options.critical)
                    else:
                        exitcode = 0
                        print "%s is %ds old (lt %d lt %d)" % (options.string, \
                                delta, options.warning, options.critical)
        else:
            exitcode = 3
            print "Updater string not found in version data."
            print "Found:"
            key_list = updater_ts.keys()
            key_list.sort()
            for key in key_list:
                print key


    client.close()
    sys.exit(exitcode)
