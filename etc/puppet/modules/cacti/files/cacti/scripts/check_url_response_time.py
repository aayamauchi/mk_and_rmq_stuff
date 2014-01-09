#!/usr/bin/python26

# -*- coding: ascii -*-

# Hits a basic url, subtracts the response time for that, from a complex url,
# to calculate application response time, minus network response time.

import base64
import os
import socket
import sys
import traceback
import time
import re
import urllib2
from urlparse import urlparse

from optparse import OptionParser

def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    parser = OptionParser()
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="Database to make changes to")
    parser.add_option("-p", "--proto", type="string", dest="proto",
                            help="Potocol to use. default=http", default="http")
    parser.add_option("-b", "--basic", type="string", dest="basic",
                            help="Basic url to get network response time from.")
    parser.add_option("-c", "--complex", type="string", dest="complex",
                            help="Complex url to get application response time form.")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    exitflag = 0
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

options = init()
basicurl = '%s://%s/%s' % (options.proto, options.host, options.basic)
complexurl = '%s://%s/%s' % (options.proto, options.host, options.complex)

if options.verbose: print "Hitting %s for basic time stats" % (basicurl)
basictime = time.time()
if options.verbose: print "basictime start: %s" % (basictime)
client = urllib2.urlopen(basicurl)
basictime = time.time() - basictime
if options.verbose: print "basictime total: %s" % (basictime)
if options.verbose: print "Hitting %s for complex time stats" % (complexurl)
complextime = time.time()
if options.verbose: print "complextime start: %s" % (complextime)
client = urllib2.urlopen(basicurl)
complextime = (time.time() - complextime) 
if options.verbose: print "complextime total: %s" % (complextime)
complextime = complextime - basictime
if options.verbose: print "complextime sum: %s" % (complextime)

print complextime	    

