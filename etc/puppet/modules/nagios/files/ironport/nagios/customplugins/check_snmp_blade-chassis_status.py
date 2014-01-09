#!/usr/bin/env python26

# -*- coding: ascii -*-

import warnings
warnings.filterwarnings('ignore', '.*', DeprecationWarning)
import base64
import os
import socket
import sys
import traceback
import time

from pysnmp.entity.rfc3413.oneliner import cmdgen

from optparse import OptionParser

def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    parser = OptionParser()
    parser.add_option("-H", "--hostname", type="string",
                            help="Hostname of Blade Chassis to check")
    parser.add_option("-s", "--string", type="string",
                            help="snmp community string")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose", default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")
    if not options.hostname:
        sys.stderr.write("No hostname entered\n")
	parser.print_help()
        sys.exit(3)
    return options

def check_chassis_status():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    oid = "1.3.6.1.4.1.232.22.1.3"
    oid = tuple([int(x) for x in oid.split('.')])
    try:
        results = cmdgen.CommandGenerator().bulkCmd(
            cmdgen.CommunityData('test-agent', options.string, 1),
            cmdgen.UdpTransportTarget((options.hostname, 161)), 5, 5, oid)
    except socket.gaierror, why:
        print("socket.gaierror: " + str(why) )
        sys.exit(3)
    if options.verbose:
        print results
    if not results[3]:
        print("no data returned from installed licenses query")
        sys.exit(3)

    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")
    return results[3][0][0][1]

options = init()
states = {1: 'other', 2: 'ok', 3: 'degraded', 4: 'failed'}
state = check_chassis_status()
if state == 2:
    exit = 0
    print "%s state is OK." % (options.hostname)
elif state in states:
    exit = 2
    print "%s state is %s." % (options.hostname, states[state])
else:
    exit = 3
    print "%s state is unknown [%s]" % (options.hostname, state)


sys.exit(exit)
