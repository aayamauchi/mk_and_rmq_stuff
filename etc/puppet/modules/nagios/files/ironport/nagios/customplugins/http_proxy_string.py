#!/usr/bin/python26 -u
# -*- coding: ascii -*-
"""Base python
    code template"""

import sys
import os
import simplejson
import tempfile
import socket
import urllib
import time

from optparse import OptionParser

def funcname(enter=True, forceverbose=False):
    """Display function name of parent function"""
    try:
        if forceverbose or options.verbose:
            if enter:
                sys.stderr.write(">>DEBUG start - %s()\n" % (sys._getframe(1).f_code.co_name))
            else:
                sys.stderr.write(">>DEBUG end   - %s()\n" % (sys._getframe(1).f_code.co_name))
    except NameError:
        # options does not exist.
        return

def init():
    """collect option information, display help text if needed, set up debugging"""
    parser = OptionParser()
    default = {}
    help = {}
    help_strings = ['string', 'proxy', 'url']
    help_ints = ['warning', 'critical']
    default['string'] = 'IronPort'
    default['proxy'] = None
    default['url'] = None
    default['warning'] = 4
    default['critical'] = 8
    help['string'] = 'String to check for, in final output.\n'
    help['string'] += 'Default = %s' % (default['string'])
    help['proxy'] = 'URI to proxy host (https://host | http://host).\n'
    help['proxy'] += 'Default = %s' % (default['proxy'])
    help['url'] = 'Final URL to query.\n'
    help['url'] += 'Default = %s' % (default['url'])
    help['warning'] = 'Throw Warning if query takes longer than this.\n'
    help['warning'] += 'Default = %s' % (default['warning'])
    help['critical'] = 'Throw Critical if query takes longer than this.\n'
    help['critical'] += 'Default = %s' % (default['critical'])
    for str in help_strings:
        parser.add_option("-%s" % (str[0]), "--%s" % (str), type="string", dest=str,
                                default=default[str], help=help[str])
    for int in help_ints:
        parser.add_option("-%s" % (int[0]), "--%s" % (int), type="int", dest=int,
                                default=default[int], help=help[int])
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    funcname(True, options.verbose)
    error = 0
    if options.proxy is None or options.proxy == '':
        error = 1
        print "Must pass --proxy"
    if options.url is None or options.url == '':
        error = 1
        print "Must pass --url"
    if error:
        parser.print_help()
        sys.exit(3)
    funcname(False, options.verbose)
    return options

def hit_url_by_proxy():
    """Hits a url by a proxy, and tests for a string."""
    funcname()
    # Never wait longer than twice critical
    timeout = options.critical * 2
    socket.setdefaulttimeout(timeout)
    exit = None
    proxies = {options.proxy.split(':')[0]: options.proxy}
    if options.verbose:
        print "Using %s for proxies." % (proxies)
    start = time.time()
    try:
        f = urllib.urlopen(options.url, proxies=proxies)
    except:
        print "Error initiating connection to proxy."
        exit = 2
        output = ''
    else:
        output = f.read()
    
    if options.string not in output and exit is None:
        print "%s not in output.  --verbose for full output." % (options.string)
        if options.verbose:
            print output
        exit = 2
    seconds = time.time() - start

    if seconds >= options.critical and exit is None: 
        print "%s in output, but query took %.2f >= %s" % (options.string, seconds, options.critical)
        exit = 2
    elif seconds >= options.warning and exit is None:
        print "%s in output, but query took %.2f >= %s" % (options.string, seconds, options.warning)
        exit = 1
    elif exit is None:
        print "%s in output. (%.2fs)" % (options.string, seconds)
        if options.verbose:
            print output
        exit = 0
    funcname(False)
    if exit is None:
        exit = 3
    return exit

if __name__ == '__main__':
    options = init()
    try:
        exit = hit_url_by_proxy()
    except:
        print "Unexpected error."
        sys.exit(3)
    else:
        sys.exit(exit)
