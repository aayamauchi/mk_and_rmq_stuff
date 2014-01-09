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
    parser.add_option("-w", "--webcathost", type="string", dest="webcathost",
                            help="Webcat host.")
    parser.add_option("-u", "--user", type="string", dest="user",
                            help="Webcat user.")
    parser.add_option("-p", "--passwd", type="string", dest="passwd",
                            help="Webcat passwd.")
    parser.add_option("-t", "--test", type="string", dest="test",
                            help="Test to run.")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stdout")

    (options, args) = parser.parse_args()
    tests = ['getStatuses', 'getComplaints', 'getCats']
    error = 0
    if not options.webcathost:
        print "--webcathost required"
        error = 1
    if not options.user:
        print "--user required"
        error = 1
    if not options.passwd:
        print "--passwd required"
        error = 1
    if not (options.test) or (options.test not in tests):
        print "Valid options for --test are:"
        for test in tests:
            print test,
        print
        error = 1
    if options.verbose: sys.stdout.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stdout.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: sys.stdout.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return options


def run_test(test):
    if options.verbose: sys.stdout.write(">>DEBUG start - " + funcname() +
                            "()\n")
    base_url = "https://%s" % (options.webcathost)
    url = "%s/login?screen=login&username=%s&password=%s&action:Login=login" % \
                (base_url, options.user, options.passwd)
    if options.verbose:
        print "Hitting login url,", url
    try:
        request = ClientCookie.Request(url)
        response = ClientCookie.urlopen(request)
    except urllib2.HTTPError, e:
        print "CIWAC API - Login Failed: %d" % (e.code or 'unknown')
        sys.exit(2)
    if options.verbose:
        print "Logged in, code: %s" % (response.code)

    cj = ClientCookie.CookieJar()
    cj.extract_cookies(response, request)

    testurl = {}
    testurl['getStatuses'] = \
                "%s/complaints/complaints_chooser?action=GetStatuses&format=json" % (base_url)
    testurl['getComplaints'] = \
                "%s/complaints/complaints_chooser?action=GetComplaints&format=json" % (base_url)
    testurl['getComplaints'] = \
                "%s&tag=no_cat&udate_after=1&udate_before=1244677594&status=resolved" % (testurl['getComplaints'])
    testurl['getCats'] = \
                "%s/complaints/complaints_chooser?action=GetCats&format=json" % (base_url)

    if options.verbose:
        print "Hitting url %s for test %s" % (testurl[test], test)
    try:
        request2 = ClientCookie.Request(testurl[test])
        cj.add_cookie_header(request2)
        response2 = ClientCookie.urlopen(request2)
    except urllib2.HTTPError, e:
        print "CIWAC API Test url failed, code: %s" % (e.code or 'unknown')
        sys.exit(2)
    if options.verbose: print "Headers:\n", response2.info()
    decoded = response2.read()
    if options.verbose:
        print "Output:\n", decoded
    try:
        decoded = simplejson.loads(decoded)
    except:
        print "Failed to get JSON from %s" % (options.webcathost)
        sys.exit(2)
    exit = 3
    try:
        if decoded['Status'] == 'OK':
            print "CIWAC API %s OK, Message: %s" % (test, decoded['Message'])
            exit = 0
        else:
            print "CIWAC API %s CRITICAL, Message: %s" % (test, decoded['Message'])
            exit = 2
    except:
        print "CIWAC API %s CRITICAL, Output: %s" % (test, response2.read()[0:40])
        exit = 2
    if options.verbose: sys.stdout.write(">>DEBUG end    - " + funcname() +
                            "()\n")
    sys.exit(exit)

errors = 0
options = init()

run_test(options.test)


