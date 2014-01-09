#!/usr/bin/env python26

# -*- coding: ascii -*-

# polls mgas to check for expired licenses.
# Mike Lindsey (mlindsey@ironport.com) 10/18/2007

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
                            help="Hostname of MGA to check")
    parser.add_option("-s", "--string", type="string",
                            help="snmp community string")
    parser.add_option("-l", "--license", type="string",
                            help="License to check.  Do not pass, for list of licenses.")
    parser.add_option("-c", "--critical", type="int",
                            help="Threshold in seconds before critical alert.")
    parser.add_option("-w", "--warning", type="int",
                            help="Threshold in seconds before warning alert.")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose", default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")
    #if options.hostname is None or not options.hostname:
    #if options.hostname is None:
    if not options.hostname:
        sys.stderr.write("No hostname entered\n")
	parser.print_help()
        sys.exit(3)
    #if options.string is None or not options.string:
    #if options.string is None:
    if not options.string:
        sys.stderr.write("No snmp community string entered\n")
	parser.print_help()
        sys.exit(3)
    return options

def getinstalledlicenses():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    oid = "1.3.6.1.4.1.15497.1.1.1.12.1.2"
    oid = tuple([int(x) for x in oid.split('.')])
    try:
        results = cmdgen.CommandGenerator().bulkCmd(
            cmdgen.CommunityData('test-agent', options.string, 1),
            cmdgen.UdpTransportTarget((options.hostname, 161)), 5, 5, oid)
    except socket.gaierror, why:
        print("socket.gaierror: " + str(why) )
        sys.exit(3)

    if not results[3]:
        print("no data returned from installed licenses query")
        sys.exit(3)
    results[3].pop()

    licenses = []
    for license in results[3]:
        licenses.append(license[0][1])
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")
    return licenses

def checklicense():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    try:
        licensenum = licenses.index(options.license)
    except ValueError:
        print("License: " + options.license + " is not installed.")
        sys.exit(3)
    if licensenum is -1:
        sys.stderr.write("Invalid License\n")
        sys.exit(3)
    licensenum = licensenum + 1
    oid = "1.3.6.1.4.1.15497.1.1.1.12.1.3." + str(licensenum)
    oid = tuple([int(x) for x in oid.split('.')])
    results = cmdgen.CommandGenerator().getCmd(
        cmdgen.CommunityData('test-agent', options.string, 1),
        cmdgen.UdpTransportTarget((options.hostname, 161)), oid)

    if not results[3]:
        print("no data returned from perpetual query")
        sys.exit(3)
    if results[3][0][1] == 1:
        return -1 
    oid = "1.3.6.1.4.1.15497.1.1.1.12.1.4." + str(licensenum)
    oid = tuple([int(x) for x in oid.split('.')])
    results = cmdgen.CommandGenerator().getCmd(
        cmdgen.CommunityData('test-agent', options.string, 1),
        cmdgen.UdpTransportTarget((options.hostname, 161)), oid)

    if not results[3]:
        print("no data returned from expire time query")
        sys.exit(3)
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")
    return results[3][0][1]

def verifylicense():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    if timetoexpire == -1:
        print("OK: License for: " + options.license + " is perpetual")
        sys.exit(0)
    if options.critical and timetoexpire < options.critical:
        print("Critical: License for: " + options.license + " expires in " + str(timetoexpire) + " seconds.")
        sys.exit(2)
    if options.warning and timetoexpire < options.warning:
        print("Warning: License for: " + options.license + " expires in " + str(timetoexpire) + " seconds.")
        sys.exit(1)
    print("OK: License for: " + options.license + " expires in " + str(timetoexpire) + " seconds.")
    sys.exit(0)
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")

options = init()
licenses = getinstalledlicenses()
if options.license and options.license is not "-":
    timetoexpire = checklicense()
else:
    sys.stdout.write("Installed Licenses:\n")
    for license in licenses:
        print license
    sys.exit(3)
if options.critical or options.warning:
    verifylicense()
else:
    if timetoexpire == -1:
        print("License for: " + options.license + " is perpetual")
        sys.exit(0)
    print("License for: " + options.license + " expires in " + str(timetoexpire) + " seconds.")
    sys.exit(0)

sys.stderr.write("Something odd happened in run\n");
sys.exit(3)
