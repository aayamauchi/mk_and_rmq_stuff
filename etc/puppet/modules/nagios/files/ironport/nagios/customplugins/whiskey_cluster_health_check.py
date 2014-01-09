#!/usr/bin/env python26

"""
 Script for checking Whiskey Feed/Rule cluster health.
"""
EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

import json
import urllib2
import sys
import hashlib
from optparse import OptionParser

parser = OptionParser()

parser.add_option("-H", "--host", dest="host",
                        help="Hostname of checked node. " )
parser.add_option("-p", "--port", dest="port", default=80, type="int",
                        help="Port thrrough which access method. Default == 80")
parser.add_option("-P", "--proto", dest="proto", default="http", type="str",
                        help="Protocol to use" )
parser.add_option("-m", "--method", dest="method", type="str",
                        help="Path where JSON data can be retrieved. " +
                         "Defualt node_status.json", default="node_status.json")
parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                         default=False, help="Verbose output")
parser.add_option("-l", "--list", dest="list", type="str",
                        help="List of Plugins/Adapters that should be present in cluster")

(options, args) = parser.parse_args()

""" Parsing options """

if options.host == None or options.host == '':
    print("HostName Must be specified\n")
    sys.exit(EXIT_UNK)

if options.port == None or options.port =='' or options.port == 0:
    print("Port cannot be empty or Zero\n")
    sys.exit(EXIT_UNK)

if options.proto == None or options.proto == '':
    print("Protocol cannot be empty")
    sys.exit(EXIT_UNK)
else:
    if options.proto != "http" and options.proto != "https":
        print("Supported protocols http and https without trailing colon (:) and slashes (//)\n")
        sys.exit(EXIT_UNK)

if options.method == None or options.method == '':
    print("Method cannot be empty\n")
    sys.exit(EXIT_UNK)

if options.list == None or options.list == '':
    print("List of Plugins/Adapters cannot be empty\n")
    sys.exit(EXIT_UNK)
else:
    if options.list.count(',') or options.list.count('.') or options.list.count(':'):
        print("Commas not permitted\n")
        sys.exit(EXIT_UNK)


if options.verbose:
    print "Options".center(80, '-')
    print "Hostname : %s " % options.host
    print "Protocol : %s " % options.proto
    print "Port     : %d " % options.port
    print "Method   : %s " % options.method
    print "List     : %s " % options.list
    print '-' * 80

""" Generating URL to retirive data.
    Consist of Proto + $HOSTNAME$ + port """

url = str(options.proto) + "://" + str(options.host) +  ":" + str(options.port) + "/" + str(options.method)

if options.verbose:
    print "Generated URL".center(80, '-')
    print " %s " % url
    print '-' * 80

""" Trying to reach generated URL and read status of App server """

try:
    op_url = urllib2.urlopen(url)
except ( urllib2.URLError, urllib2.HTTPError ) as err_msg:
    if options.verbose:
        sys.stderr.write("Error during retrieving URL : " + str(url) + "\n")
        sys.stderr.write(str(err_msg) + "\n")
    print("ERROR. Node_Status cannot be retrieved \n")
    sys.exit(EXIT_CRIT)
else:
    md5_json =  op_url.readline()
    status_retrieved = ("".join(op_url.readlines()))
    status_md5 = hashlib.md5(status_retrieved)
    status_hash = status_md5.hexdigest()
    if str(md5_json).rstrip('\n') == str(status_hash):
        if options.verbose:
            print '*' *  80
            print "Hashes are equal".center(80)
            print "MD5 hashes".center(80, '-')
            print "md5 json    = %s " % md5_json.rstrip('\n')
            print "status_hash = %s " % status_hash
            print '-' * 80

        status = json.loads(status_retrieved)

        """ Checking response for node_state values """
        nodes_in_cluster = []
        for i in status.keys():
            nodes_in_cluster.append(str(status[i]['node_state']))

        """ Comparision if Plugins/Adapters name are present in the list """
        list_names = options.list.split(' ')

        missed = []

        for i in list_names:
            if i not in nodes_in_cluster:
                missed.append(str(i))

        if options.verbose:
            print 'User/Returned/Missed Plugins and Adapters'.center(80,'-')
            sys.stderr.write("USER SPECIFIED LIST : \n")
            print " %s " % (", ".join(i for i in list_names))
            sys.stderr.write("RETURNED NODE STATES :\n")
            print " %s " % (", ".join(i for i in nodes_in_cluster))
            sys.stderr.write("MISSED PLUGINS/ADAPTERS: \n")
            print " %s " % (", ".join(i for i in missed ))
            print '-' * 80

        """ Comparision Thresholds """
        if len(missed) != 0:
            print("CRITICAL. Next Plugins/adapters are not found " + str(missed) + "\n")
            sys.exit(EXIT_CRIT)
        else:
            print("OK. All Plugins/Adapters are in place\n")
            sys.exit(EXIT_OK)

    else:
        if options.verbose:
            print '*' *  80
            print "Hashes are not equal".center(80)
            print "MD5 hashes".center(80, '-')
            print "md5 json    = %s " % md5_json.rstrip('\n')
            print "status_hash = %s " % status_hash
            print '-' * 80

        print("ERROR. MD5 Hashes are not equal \n")
        sys.exit(EXIT_CRIT)
