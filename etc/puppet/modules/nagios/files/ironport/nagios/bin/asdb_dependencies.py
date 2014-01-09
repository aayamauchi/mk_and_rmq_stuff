#!/usr/bin/env python26
"""Script for parsing out dependencies for a product.

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
    usage = """usage: %prog --host [host]"""
    parser = OptionParser(usage=usage)
    parser.add_option("--host", type="string", dest="host",
                            help="Host to get dependency data for")
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
    import pprint
    try:
        productdoc = asdb.hostdata(options.host)[0]['product']
    except:
        try:
            productdoc = asdb.roledata(options.host)[0]['product']
        except:
            print "Error pulling product relationship data from ASDB."
            sys.exit()

    if 'productrelationship' not in productdoc['related'] or \
            len(productdoc['related']['productrelationship']) == 0:
        print "No documented relationships."
    else:
        product = productdoc['name']
        productdoc = productdoc['related']['productrelationship']
        for item in productdoc.keys():
            print "%s depends on %s" % \
                    (productdoc[item]['dependent'], productdoc[item]['dependency'])
            print " -",
            if productdoc[item]['notes']:
                print productdoc[item]['notes']
            else:
                print "No documented notes."

