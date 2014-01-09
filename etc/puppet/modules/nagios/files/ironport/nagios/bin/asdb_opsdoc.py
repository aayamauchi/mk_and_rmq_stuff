#!/usr/bin/env python26
"""Script for parsing out OpsDoc URLs for a product.

Mike Lindsey <miklinds@cisco.com>  11/3/2010
"""
 
# -*- coding: ascii -*-

import sys
import os
import time

import asdb

from optparse import OptionParser

def funcname():
    """so we don't have to keep doing this over and over again."""
    return sys._getframe(1).f_code.co_name

def init():
    """collect option information, display help text if needed, set up debugging"""
    usage = """usage: %prog --product [product]"""
    parser = OptionParser(usage=usage)
    parser.add_option("--host", type="string", dest="host",
                            help="Host to get ProductDoc data for")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    error = 0
    if not options.host:
        sys.stderr.write("Missing --host\n")
        error += 1

    if error:
        parser.print_help()
        sys.exit(3)
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return options


if __name__ == '__main__':
    options = init()
    try:
        productdoc = asdb.hostdata(options.host)[0]['product']['related']['productdoc']
    except:
        try:
            productdoc = asdb.roledata(options.host)[0]['product']['related']['productdoc']
        except:
            print "Error pulling productdoc data from ASDB."
            sys.exit()

    if productdoc.keys():
        for item in productdoc.keys():
            print "%s: %s" % (productdoc[item]['type'], productdoc[item]['url'])
            print "Desc: %s" % (productdoc[item]['description'])
    else:
        print "No OpsDoc available."

