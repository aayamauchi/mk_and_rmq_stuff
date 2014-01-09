#!/bin/env python2.6

import sys
import urllib2
import json
import os
import time

from optparse import OptionParser
import optparse

EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

def get_file_exist(filename):
    """Function checks if filename exists"""
    if (os.path.exists(os.path.abspath(filename))):
        if options.verbose:
            print "File %s exists " % (os.path.abspath(filename))
        return True
    else:
        if options.verbose:
            print "File %s does not exist" % (os.path.abspath(filename))
        print "Might be 1st run"
        return False


def read_data_from_file(filename):
    """ 
        Trying to  open file for reading. 
        If successfully - returns previous counter's value and previous timestamp.
    """ 

    try:
        fileid = open(filename, 'r' )
    except (IOError, EOFError ) as err_msg:
        print "Error Opening File".center(80, '-')
        print err_msg
        print "Error Opening File".center(80, '-')
        print "UNKNOWN. Cannot open file %s for reading" % filename
        sys.exit(EXIT_UNK)
    else:
        read_values = fileid.readlines()
        if len(read_values) == 0:
            print "No Data read from file"
            print "Assuming 1st run. Assigning 0(zero) for counter's value variable"
            value_read = 0
            time_read = now
        else:
            value_read = int(read_values[0].splitlines()[0])
            time_read = int(read_values[1].splitlines()[0])
        fileid.close()
        return value_read, time_read



def store_data_to_file(filename, counter_value, timestamp):
    """Storing data to file"""
    try:
        fileid = open(filename, 'w' )
    except IOError, err_msg:
        print "Error Opening File For Data Storing".center(80, '-')
        print err_msg
        print "Error Opening File For Data Storing".center(80, '-')
        print "UNKNOWN. Cannot open file %s for data storing" % filename
        sys.exit(EXIT_UNK)
    else:
        fileid.writelines(str(counter_value) + '\n')
        fileid.writelines(str(timestamp) + '\n')
        fileid.close()


parser = OptionParser()

parser.add_option("-H", "--host", dest="host",
                        help="Hostname where to look for counters")
parser.add_option("-d", "--daemon", dest="daemon",
                        help="Could be either \"packaged\" or \"publishinig\" or \"splitter\"")
parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                         default=False, help="Verbose output")
parser.add_option("-c", "--critical", type="int", dest="critical", default=0,
                        help="Critical threshold. Default = 0. Just for COUNTERS method")
parser.add_option("-n", "--name", dest="name",
                        help="Counter's Name to check")

try:
    (options, args) = parser.parse_args()
except optparse.OptParseError,  err:
    print err
    sys.exit(EXIT_UNK)

daemon_list = {'packaged':12100, 'publishing':12300, 'packaged':12200}

if options.daemon not in sorted(daemon_list.keys()):
    print "Supported daemon are %s" % ','.join(i for i in sorted(daemon_list.keys()))
    print "UNKNOWN. Not supported method %s " % options.daemon
    sys.exit(EXIT_UNK)

if options.name == None or options.name == '' :
    ErrMsg = "You should specify counter's name \n"
    sys.stderr.write(ErrMsg)
    sys.exit(EXIT_UNK)


# Generating filename and path for storing data

filename = os.path.join('/tmp', (os.path.splitext(os.path.split(sys.argv[0])[1])[0]  + '-' + options.name.replace(':', '-') + ".txt"))

if options.verbose:
    print "File name and path successfully generated"
    print "File Name : %s " % os.path.split(filename)[1]
    print "File Path : %s " % os.path.split(filename)[0]
    print "Full Path : %s " % filename

""" Selecting port to connect to based on the daemon"""
if options.verbose:
    sys.stderr.write(">>DEBUG start. Selecting port number \n")

port = daemon_list[options.daemon]

if options.verbose:
    sys.stderr.write(">>DEBUG end. Daemon " + options.daemon + " has port " + str(port) + "\n\n")

""" Processing """

if options.verbose:
    sys.stderr.write(">>DEBUG start. Starting processing \n")


"""
    1stly Active Node should be identified,
    Use next syntax: <proto>://<hostname>:<daemons_port>/nodes_connected?service=active
    Example: http://stage-casepkg-app2.vega.ironport.com:12300/nodes_connected?service=active
"""

url = "http://" + options.host + ":" + str(port) + "/nodes_connected?service=active"

try:
    active_node = urllib2.urlopen(url).read()
except ( urllib2.URLError, urllib2.HTTPError ) as err_msg:
    sys.stderr.write("Error Occured: " + str(err_msg) + "\n" )
    sys.stderr.write("Exiting with UNKNOWN state \n")
    sys.exit(EXIT_CRIT)

active_host = active_node.split(":")[0]
url = "http://" + str(active_host) + ":" + str(port) + "/counters.json"

try:
    tmp = json.loads(urllib2.urlopen(url).read())
except ( urllib2.URLError, urllib2.HTTPError ) as err_msg:
    sys.stderr.write("Error Occured: " + str(err_msg) + "\n" )
    sys.stderr.write("Exiting with UNKNOWN state \n")
    sys.exit(EXIT_CRIT)

if options.verbose:
    sys.stderr.write(">>DEBUG. Downloaded Counters \n")
    print json.dumps(tmp, indent=4)

# Getting timestamp when the counter was retrieved
now = int(time.time())

try:
    counter_value = tmp[options.name]
except KeyError as ErrMsg:
    sys.stderr.write("Error. Bad Counter Name :: " + str(options.name) + "\n")
    sys.stderr.write("Exiting with UNKNOWN state\n")
    sys.exit(EXIT_CRIT)

if options.verbose:
    sys.stderr.write(">>DEBUG started. Retrived counter's value\n")

# Checking if file with the results from previous run exist.
# If not exist trying to create.

if get_file_exist(filename):
    """ If file exist trying to read data from it """

    value_read, time_read = read_data_from_file(filename)

    delta = counter_value - value_read

    if options.verbose:
        print "VALUES FROM FILE".center(80, '-')
        print "%-40s: %d" % ("Counter's value is", value_read)
        print "%-40s: %s" % ("Timestamp value is", time_read)
        print "%-40s: %d" % ("Retrieved Value is", counter_value)
        print "%-40s: %d" % ("Delta Value", delta)
        print "VALUES FROM FILE END".center(80, '-')

else:
    # If this is first  run there is no previous retrieved counter's value.
    # Asssuming zero (0) values for calculation.
    if options.verbose:
        print "Assiging 0 for previous counter value"
        print "Assigning current time for previous timestamp"

    value_read = 0
    time_read = now
    delta = counter_value - value_read

if delta > options.critical: 
    if options.verbose:
        print "DELTA OK CONDITION".center(80, '-')
        print "%-40s: %d" % ("Delta value", delta)
        print "%-40s: %d" % ("Read Value", value_read)
        print "%-40s: %d" % ("Retrieved Value", counter_value)
        print "%-40s: %s" % ("Time Read", time.ctime(time_read))
        print "%-40s: %s" % ("Time when last counter is retrieved is", time.ctime(now))
        print "DELTA OK CONDITION END".center(80, '-')

    # Storing new data into the file
    store_data_to_file(filename, counter_value, now)

    print "OK. Delta between retrieved and previous values for counter %s is %d " % (options.name, delta)
    sys.exit(EXIT_OK)

else:
    if options.verbose:
        print "NON OK CONDITION".center(80, '-')
        print "%-40s: %s" % ("Time read from file is ", str(time.ctime(time_read)))
        print "%-40s: %s" % ("Time when last counter is retrieved is ", str(time.ctime(now)))
        print "%-40s: %d" % ("Read Counter's value is", value_read)
        print "%-40s: %d" % ("Retrieved counter's value is", counter_value)
        print "%-40s: %d" % ("Delta is", delta)
        print "NON OK CONDITION END".center(80, '-')

    # Storing new data to the file
    store_data_to_file(filename, counter_value, time_read)
    print "CRITICAL.Counter %s %s %s. Delta is %d" % ( options.name, "hasn't changed since", time.ctime(time_read), delta)
    sys.exit(EXIT_CRIT)

