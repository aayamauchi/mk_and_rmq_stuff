#!/usr/bin/python26

# -*- coding: ascii -*-

# IronPort Custhelp check script, repurposed from CIWAC check script.
# Original author (CIWAC script): Mike Lindsey (mlindsey@ironport.com) 
# Revisions for IronPort Custhelp: Jeff Ramacher (MONOPS-669).

import base64
import os
import socket
import sys
import traceback
import time
import urllib2
from urlparse import urlparse
import ClientCookie
import re

from optparse import OptionParser

def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    parser = OptionParser()
    parser.add_option("-w", "--wwwhost", type="string", dest="wwwhost",
                            help="WWW host.")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stdout")

    (options, args) = parser.parse_args()
    if options.verbose: sys.stdout.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stdout.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: sys.stdout.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return options


def run_test():
    if options.verbose: sys.stdout.write(">>DEBUG start - " + funcname() + "()\n")
    base_url = "https://%s" % (options.wwwhost)
    url = "%s/cgi-bin/ironport.cfg/php/enduser/std_alp.php?p_sid=UYBQdGej&p_accessibility=0&p_redirect=0&p_lva=772&p_li=cF91c2VyaWQ9MXJvblAwcnQmcF9wYXNzd2Q9Zm8wQmE1" % (base_url)
    search_str = "An IronPort Customer"
    if options.verbose:
        print "Hitting url,", url
    try:
        request = ClientCookie.Request(url)
        response = ClientCookie.urlopen(request)
    except:
        print "CRITICAL - Error with server request and response"
        sys.exit(2)
    if options.verbose:
        print "Connected, response code: %s" % (response.code)

    cj = ClientCookie.CookieJar()
    cj.extract_cookies(response, request)

    if search_str not in response.read():
        print "CRITICAL - Search string not found in result: %s" % (search_str)
        sys.exit(2)
    else:
        print "OK - Search string found: %s" % (search_str)

errors = 0
options = init()

run_test()
sys.exit(0)
