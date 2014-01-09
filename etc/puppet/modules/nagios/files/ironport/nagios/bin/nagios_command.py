#!/usr/bin/env python26

# -*- coding: ascii -*-

# Reads in nagios config, dumps out command that nagios is running
# Mike Lindsey (mlindsey@ironport.com) 6/5/2008


import base64
import os
import socket
import sys
import traceback
import time
import re
import simplejson
import datetime

from optparse import OptionParser

fileroot = '/usr/local/nagios/etc/'
resourcefiles = ('resource.cfg')

def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    parser = OptionParser()
    parser.add_option("-H", "--Host", type="string", dest="host",
                            help="hostname")
    parser.add_option("-S", "--Service", type="string", dest="service",
                            help="service")
    parser.add_option("-s", "--statc", type="string", dest="statc",
                            help="Server stats client.", \
                            default="/usr/local/ironport/nagios/bin/nagiosstatc")
    parser.add_option("-n", "--nopw", action="store_true", dest="nopw",
                            default=False,
                            help="do not expand nagios resource macros")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    exitflag = 0
    if not options.host:
        exitflag = exitflag + 1
        print "Need host"
    if not options.service:
        exitflag = exitflag + 1
        print "Need service"
    elif ' ' in options.service:
        options.service = options.service.replace(' ', '\\ ')
    if exitflag > 0:
        parser.print_help()
        sys.exit(0)
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

    return options

def get_resources():
    """We have to hit local disk for resource macros, as
    they contain passwords, and should not be made available
    over the stats socket."""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() +
                            "()\n")
    resources = ''
    f = open(fileroot + resourcefiles)
    resources = resources + f.read()

    resourcelist  = resources.split('$USER')
    resourceclean = {}

    i = 0
    for resource in resourcelist:
        if i > 0:
            arg = resourcelist[i].split('$')[0]
            value = resourcelist[i].split('=')[1].split('\n')[0]
            resourceclean[arg] = value
        i = i + 1

    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() +
                            "()\n")
    return resourceclean

def expand(bit):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")

    if bit in ['_SERVICEWARN', '_SERVICECRIT']:
        # setup variables for chronos _WARN and _CRIT strings
        dt = datetime.datetime.now()
        weekday = dt.weekday()
        hour = dt.timetuple()[3]
        try:
            if 'CRIT' in bit:
                bit = svchash['_CRIT'].split()[(weekday*24)+hour]
            elif 'WARN' in bit:
                bit = svchash['_WARN'].split()[(weekday*24)+hour]
        except:
            bit = 'err(%s)' % (bit)
        if options.verbose:
            print "Spotted chronos threshold, day is %i, hour is %i, grabbing slice %i" % \
                    (weekday, hour, (weekday*24)+hour)
    else:
        if 'HOST' in bit:
            bit = hosthash[bit.replace('HOST','')]
        elif 'SERVICE' in bit:
            bit = svchash[bit.replace('SERVICE','')]
        else:
            bit = 'err(%s)' % (bit)

    if options.verbose:
        sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")
    return bit

if __name__ == '__main__':
    options = init()

    try:
        resources = get_resources()
    except:
        if options.verbose:
            print "Error fetching resources from disk.  Passing empty dict."
        resources = {}

    cmd = '%s -q "object host %s"' % (options.statc, options.host)
    if options.verbose:
        print "Querying with '%s'" % (cmd)
    hosthash = os.popen(cmd).read()
    hosthash = simplejson.loads(hosthash)

    address = hosthash['address']

    if options.service:
        cmd = '%s -q "object service %s %s"' % (options.statc, options.host, options.service)
        if options.verbose:
            print "Querying with '%s'" % (cmd)
        svchash = os.popen(cmd).read()
        svchash = simplejson.loads(svchash)

        check_command = svchash['check_command'].split('!')

    else:
        check_command = hosthash['check_command'].split('!')

    cmd = '%s -q "object command %s"' % (options.statc, check_command[0])
    if options.verbose:
        print "Querying with '%s'" % (cmd)
    fullcommand = os.popen(cmd).read()
    fullcommand = simplejson.loads(fullcommand)['command_line']

    buildcommand = ''
    finalcommand = ''

    # First pass of variable expansion processes command_line of Command definition.
    for bit in fullcommand.split('$'):
        if bit == 'HOSTADDRESS':
            bit = address
        elif bit == 'HOSTNAME':
            bit = options.host
        elif bit.startswith('USER'):
            if not options.nopw:
                bit = resources.get(bit.replace('USER',''), 'err(%s)' % (bit))
            else:
                bit = '$' + bit + '$'
        elif bit.startswith('ARG'):
            try:
                bit = check_command[int(bit.replace('ARG',''))]
            except:
                # ARG values are not required to be in the check command
                bit = ''
        elif bit.startswith('_'):
            bit = expand(bit)
        buildcommand = buildcommand + bit

    # Second pass of variable expansion proceses results from the first pass.
    # Catches variables that exist in Service definitions, which is common with cluster checks.
    # Note: ARG variables are no longer expanded at this point.
    for bit in buildcommand.split('$'):
        if bit == 'HOSTADDRESS':
            bit = address
        elif bit == 'HOSTNAME':
            bit = options.host
        elif bit.startswith('USER'):
            if not options.nopw:
                bit = resources.get(bit.replace('USER',''), 'err(%s)' % (bit))
            else:
                bit = '$' + bit + '$'
        elif bit.startswith('_'):
            bit = expand(bit)
        finalcommand = finalcommand + bit

    print finalcommand