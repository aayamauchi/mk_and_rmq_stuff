#!/usr/bin/python26

# -*- coding: ascii -*-

# CIWAC check script.
# Mike Lindsey (mlindsey@ironport.com) 

import base64
import os
import socket
import sys
import traceback
import time
import urllib2
from urlparse import urlparse
import ClientCookie
import simplejson
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
    parser.add_option("-u", "--user", type="string", dest="user",
                            help="WWW user.")
    parser.add_option("-p", "--passwd", type="string", dest="passwd",
                            help="WWW passwd.")
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
    if options.verbose: sys.stdout.write(">>DEBUG start - " + funcname() +
                            "()\n")
    base_url = "https://%s" % (options.wwwhost)
    url = "%s/irppcnctr/login?emailid=%s&password=%s&task=login" % \
                (base_url, options.user, options.passwd)
    if options.verbose:
        print "Hitting login url,", url
    try:
        request = ClientCookie.Request(url)
        response = ClientCookie.urlopen(request)
    except urllib2.HTTPError, e:
        print "Support Portal - Login Failed: %d" % (e.code or 'unknown')
        sys.exit(2)
    if options.verbose:
        print "Logged in, code: %s" % (response.code)

    cj = ClientCookie.CookieJar()
    cj.extract_cookies(response, request)

    if 'Welcome Automated Monitor' not in response.read():
        print "Support Portal - Login Failed string test."
        sys.exit(2)

    url = "%s/irppcnctr/srvcd?u=http://secure-support.soma.ironport.com" % (base_url)
    url = "%s/subproducts/s_series/ciwac_submitted_urls.html&sid=900019" % (url)
    if options.verbose:
        print "Hitting url %s for test" % (url)
    try:
        request2 = ClientCookie.Request(url)
        cj.add_cookie_header(request2)
        response2 = ClientCookie.urlopen(request2)
    except urllib2.HTTPError, e:
        print "Support Portal WSA CIWAC admin submission get failed: %s" % (e.code or 'unknown')
        sys.exit(2)
    if options.verbose: print "Headers:\n", response2.info()

    output = response2.read()
    if 'Filter on' not in output:
        print "Portal WSA CIWAC admin submission unable to retrieve statuses"
        if options.verbose:
            print "Output:\n", output 
        sys.exit(2)
    print "Support Portal OK"
    if options.verbose: sys.stdout.write(">>DEBUG end    - " + funcname() +
                            "()\n")

errors = 0
options = init()

run_test()
sys.exit(0)
