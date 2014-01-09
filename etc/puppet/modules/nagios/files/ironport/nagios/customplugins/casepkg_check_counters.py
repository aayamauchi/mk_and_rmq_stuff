#!/bin/env python2.6

import sys
import urllib2
import json

from optparse import OptionParser

EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

parser = OptionParser()

parser.add_option("-H", "--host", dest="host",
                        help="Hostname where to look for counters")
parser.add_option("-m", "--method", dest="method",
                        help="Could be either \"nodes_connected\" or \"counters\"")
parser.add_option("-d", "--daemon", dest="daemon",
                        help="Could be either \"packaged\" or \"publishinig\" or \"splitter\"")
parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                         default=False, help="Verbose output")
parser.add_option("-w", "--warning", type="int", dest="warning", default=0,
                        help="Warning threshold. Default = 0. Just for COUTNERS method")
parser.add_option("-c", "--critical", type="int", dest="critical", default=0,
                        help="Critical threshold. Default = 0. Just for COUNTERS method")
parser.add_option("-n", "--name", dest="name",
                        help="Counter's Name to check")
parser.add_option("-N", "--nodes_ok", type="int", dest="nodes",
                        help="Amount of configured nodes. Just for NODES_CONNECTED method")

(options, args) = parser.parse_args()

if options.daemon != "packaged" and options.daemon != "publishing" and options.daemon != "splitter":
    ErrMsg = "Unsupported mode %s !!! Supported just \"packaged\" or \"publishing\" or \"splitter\"" % (options.mode)
    print ErrMsg
    sys.exit(EXIT_UNK)

if options.method != "nodes_connected" and options.method != "counters":
    ErrMsg = "Uknown method %s. Supported just  \"nodes_connected\" or \"counters\" " % (options.method)
    print ErrMsg
    sys.exit(EXIT_UNK)

if options.method == "counters":
    if options.name == None :
        ErrMsg = "You should specify counter's name \n"
        sys.stderr.write(ErrMsg)
        sys.exit(EXIT_UNK)

if options.method == 'nodes_connected':
    if options.nodes == None:
        ErrMsg = "You Must specify amount of configured nodes to check"
        sys.stderr.write(ErrMsg)
        sys.exit(EXIT_UNK)


""" Selecting port to connect to based on the daemon"""
if options.verbose:
    sys.stderr.write(">>DEBUG start. Selecting port number \n")

if options.daemon == "packaged":
    port = 12100
elif options.daemon == "publishing":
    port = 12300
elif options.daemon == "splitter":
    port = 12200
else:
    sys.stderr.write("Unknown daemon %s " % str(options.daemon))
    sys.exit(EXIT_UNK)

if options.verbose:
    sys.stderr.write(">>DEBUG end. Daemon " + options.daemon + " has port " + str(port) + "\n\n")

""" Processing """

if options.verbose:
    sys.stderr.write(">>DEBUG start. Starting processing \n")

if options.method == "nodes_connected":
    try:
        url = "http://" + options.host + ":" + str(port) + "/" + options.method
        tmp =  urllib2.urlopen(url).readlines()
    except ( urllib2.URLError, urllib2.HTTPError ) as err_msg:
        sys.stderr.write("UNKNOWN :: " + str(err_msg) + "\n")
        sys.exit(EXIT_UNK)

    nodes_amount = len(tmp)
    if nodes_amount < options.nodes:
        if options.verbose:
            sys.stderr.write(">>DEBUG started. Comparision CRITICAL condition \n")
            sys.stderr.write("Critical State Encountered \n")
            sys.stderr.write("Amount of returned nodes " + str(nodes_amount) + "\n" )
            sys.stderr.write("Needed amount of Nodes " + str(options.nodes) + "\n" )
            sys.stderr.write("Returned Nodes : " + str(tmp) + "\n")
            sys.stderr.write(">>DEBUG End \n")
        print "Critical. Amount of connected Nodes : %s " % nodes_amount
        sys.exit(EXIT_CRIT)
    else:
        if options.verbose:
            sys.stderr.write(">>DEBUG Start. Comparision OK condition \n")
            sys.stderr.write("OK State Encountered \n")
            sys.stderr.write("Amount of Nodes " + str(nodes_amount) + "\n")
            sys.stderr.write("Returned Nodes : " + str(tmp) + "\n")
            sys.stderr.write(">>DEBUG End \n")
        print "OK. Amount of connected Nodes : %s " % nodes_amount
        sys.exit(EXIT_OK)

if options.method == "counters":

    """
    1stly Active Node should be identified,
    Use next syntax: <proto>://<hostname>:<daemons_port>/nodes_connected?service=active
    Example: http://stage-casepkg-app2.vega.ironport.com:12300/nodes_connected?service=active """


    url = "http://" + options.host + ":" + str(port) + "/nodes_connected?service=active"

    try:
        active_node = urllib2.urlopen(url).read()
    except ( urllib2.URLError, urllib2.HTTPError ) as err_msg:
        sys.stderr.write("Error Occured: " + str(err_msg) + "\n" )
        sys.stderr.write("Exiting with UNKNOWN state \n")
        sys.exit(EXIT_UNK)

    active_host = active_node.split(":")[0]
    url = "http://" + str(active_host) + ":" + str(port) + "/" + options.method + ".json"

    try:
        tmp = json.loads(urllib2.urlopen(url).read())
    except ( urllib2.URLError, urllib2.HTTPError ) as err_msg:
        sys.stderr.write("Error Occured: " + str(err_msg) + "\n" )
        sys.stderr.write("Exiting with UNKNOWN state \n")
        sys.exit(EXIT_UNK)

    if options.verbose:
        sys.stderr.write(">>DEBUG. Downloaded Counters \n")
        print json.dumps(tmp, indent=4)

    try:
        counter_value = tmp[options.name]
    except KeyError as ErrMsg:
        sys.stderr.write("Error. Bad Counter Name :: " + str(options.name) + "\n")
        sys.stderr.write("Exiting with UNKNOWN state\n")
        sys.exit(EXIT_UNK)

    if options.verbose:
        sys.stderr.write(">>DEBUG started. Retrived counter's value\n")

    if counter_value >= options.critical:
        if options.verbose:
            sys.stderr.write(">>DEBUG started. Comparision CRITICAL condition \n")
            sys.stderr.write("Critical State Encountered \n")
            sys.stderr.write("Counter's Value :: " + str(counter_value) + "\n" )
            sys.stderr.write("Critical Threshold : " + str(options.critical) + "\n")
            sys.stderr.write("Host: " + str(options.host) + "\n" )
            sys.stderr.write("Active Node " +  str(active_node) + "\n" )
            sys.stderr.write("Result URL : " + str(url) + "\n" )
            sys.stderr.write(">>DEBUG End \n")
        print "CRITICAL - Counter's value is %s " % counter_value
        sys.exit(EXIT_CRIT)
    if counter_value < options.critical and counter_value >= options.warning:
        if options.verbose:
            sys.stderr.write(">>DEBUG Started. Comparision WARNING condition \n")
            sys.stderr.write("Warning State Encountered \n")
            sys.stderr.write("Counter's value :: " +  str(counter_value) + "\n")
            sys.stderr.write("Warning Threshold : " + str(options.warning) + "\n")
            sys.stderr.write("Host: " + str(options.host) + "\n" )
            sys.stderr.write("Active Node " +  str(active_node) + "\n" )
            sys.stderr.write("Result URL : " + str(url) + "\n" )
            sys.stderr.write(">>DEBUG End \n")
        print "WARNING - Counter's Value is %s " % counter_value
        sys.exit(EXIT_WARN)
    else:
        if options.verbose:
            sys.stderr.write(">>DEBUG Start. Comparision OK condition \n")
            sys.stderr.write("OK State Encountered \n")
            sys.stderr.write("Counter's value :: " + str(counter_value) + "\n")
            sys.stderr.write("Host: " + str(options.host) + "\n" )
            sys.stderr.write("Active Node " +  str(active_node) + "\n" )
            sys.stderr.write("Result URL : " + str(url) + "\n" )
            sys.stderr.write(">>DEBUG End \n")
        print "OK - Counter's Value is %s " % counter_value
        sys.exit(EXIT_OK)
