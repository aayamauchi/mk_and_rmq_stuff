#!/bin/env python26

""" Script for retrieving counters for Merlin product.
    counters-json page returns lis of dictionary
    which are parsed by the script.
    Firstly looks for an active node on the node_status page"""

import sys
import json
import urllib2
import time
import os
from BeautifulSoup import BeautifulSoup

from optparse import OptionParser

EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

daemons_dict = {'publisher':10181, 'packager':10180}
app_dict = {'publiser':'merlin_publisher', 'packager':'merlin_packager'}
counters_tuple = ("rate_d", "rate_m", "value",)

# Some functions
def generate_base_url():
    """ Function generates URL to retireve data from """

    url = "http://" + str(options.host) + ":" \
              + str(daemons_dict[options.daemon]) \
              +  str(options.counterspage)
    return url

def generate_url(host, page):
    """ Function for generating URL """

    if not host.startswith("http://"):
        host = "http://" + host

    if not host.endswith(str(daemons_dict[options.daemon])):
        host += ":" + str(daemons_dict[options.daemon])

    if not page.startswith("/"):
        host += "/" + page
    else:
        host += page

    if page.endswith('/'):
        print "INVALID Page \"%s\". Page cannot ends with \"/\" " % page
        print "UNKNOWN. Invalid page \"%s\". " % page
        sys.exit(EXIT_UNK)

    url = host
    if options.verbose:
        print "Generated URL = %s " % url

    return url

def get_tables(soup_page):
    """Function parses element for <table> headers elements
       Returns list of table elements"""

    tables_list = soup_page.findAll('table')
    return tables_list

def find_table_index_via_header(arr, keyword_header):
    """Function parses tables list using <th> tag as separator.
       Returns 1st matched index of table ,
       which has Column Name equal to keyword_header"""

    for table_index in xrange(len(arr)):
        for header in arr[table_index].findAll('th'):
            if header.text == keyword_header:
                if options.verbose:
                    print "Find Appropriate Column"
                    print "Column Index is %d " % table_index
                return table_index

def parse_table_rows(arr, active_index):
    """Function parses arr[active_index] element using <td> as separator.
       Returns hostname of 1st not standby node"""

    for i in xrange(len(arr[active_index].findAll('th'))):
        if arr[active_index].findAll('th')[i].text == 'node_state':
            node_index = i
    table_rows = arr[active_index].findAll('tr')
    for i in xrange(len(table_rows)):
        if table_rows[i].findAll('th'):
            tmp_index = i
    del table_rows[tmp_index]
    for i in table_rows:
        tmp_arr = i.findAll('td')
        if tmp_arr:
            if tmp_arr[node_index].text != 'standby':
                if options.verbose:
                    print tmp_arr[node_index].text, tmp_arr[-1].text
                    print "Active Url : %s " % tmp_arr[-1].text
                active_node = tmp_arr[-1].text

    try:
        if active_node:
            return active_node
    except UnboundLocalError:
        print "UNKNOWN. No Active nodes were found"
        sys.exit(EXIT_UNK)

def gen_file_name(counter_name_opt, file_ext='txt', target_dir='/tmp'):
    """ Function generate filename for data storing.
        Filename is created in next way:
        target_dit + script's_name + counter's_name(: are replaced to -) + extension
        E.G: /tmp/merlin_counters-merlin_publihser-retry.txt"""

    if not file_ext.startswith('.'):
        file_ext = '.' + file_ext

    ffilename = os.path.join(target_dir, \
               (os.path.splitext(os.path.split(sys.argv[0])[1])[0] + '-' \
                + counter_name_opt.replace(':', '-') + file_ext ))
    if options.verbose:
        print "GENERATED FileName is %s " % ffilename

    return ffilename

def get_file_exist(ffilename):
    """Function checks if filename exists"""
    if (os.path.exists(os.path.abspath(ffilename))):
        if options.verbose:
            print "File %s exists " % (os.path.abspath(ffilename))
        return True
    else:
        if options.verbose:
            print "File %s does not exist" % (os.path.abspath(ffilename))
            print "Might be 1st run"
        return False


def pretty_time_format(value1):
    """ Returns time in human-readable format """

    return time.strftime('%Y-%d-%m %H:%M:%S', time.localtime(int(value1)))


def read_data_from_file(ffilename):
    """
        Trying to  open file for reading.
        If successfully - returns previous counter's value and previous timestamp.
    """

    try:
        fileid = open(ffilename, 'r' )
    except (IOError, EOFError ) as err_msg:
        print "Error Opening File".center(80, '-')
        print err_msg
        print "Error Opening File".center(80, '-')
        print "UNKNOWN. Cannot open file %s for reading" % ffilename
        sys.exit(EXIT_UNK)
    else:
        read_values = fileid.readlines()
        if len(read_values) == 0:
            print "No Data read from file"
            print "1st run? Assigning 0(zero) for counter's value variable"
            value_read = 0
            time_read = script_exec_time #WAS: now
        else:
            value_read = int(read_values[0].splitlines()[0])
            time_read = int(read_values[1].splitlines()[0])

        fileid.close()
        return (value_read, time_read)



def store_data_to_file(ffilename, counter_value, timestamp):
    """Storing data to file"""
    try:
        fileid = open(ffilename, 'w' )
    except IOError, err_msg:
        print "Error Opening File For Data Storing".center(80, '-')
        print err_msg
        print "Error Opening File For Data Storing".center(80, '-')
        print "UNKNOWN. Cannot open file %s for data storing" % ffilename
        sys.exit(EXIT_UNK)
    else:
        fileid.writelines(str(counter_value) + '\n')
        fileid.writelines(str(timestamp) + '\n')
        fileid.close()


def print_verbose_timestamps(sc_time, r_time, d_time):
    """Function to print Current, Stored timestamp,
       and delta between them. Just to eliminate code """

    print "DEBUG START".center(80, '-')
    print "Current Timestamp : %s " % sc_time,
    print " | %s " % pretty_time_format(sc_time)
    print "Stored Timestmap  : %s " % r_time,
    print " | %s " % pretty_time_format(r_time)
    print "Delta             : %s " % d_time
    print "DEBUG END".center(80, '-')


def compare_values(counter_type, warn, crit):
    """ Function for Counter's Value comparision.
        3 Ways are possible:
        -  Straight Value comparision
        -  Rate for Days frequency Comparision
        -  Rate for Minutes frequency Comparision (not implemented yet)
    """

    if counter_type == 'value' or counter_type == 'rate_m':
        retrieved_value =  get_counter_value(found_counter, counter_type)

        if retrieved_value >= crit:
            print "CRITICAL. %s value is greater than %.3f " % (options.name, crit)
            sys.exit(EXIT_CRIT)
        if retrieved_value >= warn:
            print "WARNING. %s value is greater than %.3f " % (options.name, warn)
            sys.exit(EXIT_UNK)
        print "OK. %s value is within thresholds %.3f | %.3f | %.3f " % (options.name, retrieved_value, warn, crit)
        sys.exit(EXIT_OK)

    if counter_type == 'rate_d':
        retrieved_value =  get_counter_value(found_counter, counter_type)

        if get_file_exist(filename):
            read_value, read_time = read_data_from_file(filename)
        else:
            read_value = retrieved_value
            read_time = script_exec_time
            store_data_to_file(filename, retrieved_value, script_exec_time)

        if retrieved_value != read_value:
            if options.verbose:
                print "DEBUG START".center(80, '-')
                print "Retrieved Value and Stored one are not equal"
                print "Retrieved Value : %s " % retrieved_value
                print "Stored Value    : %s " % read_value
                print "DEBUG END".center(80, '-')
            store_data_to_file(filename, retrieved_value, script_exec_time)
            sys.exit(EXIT_OK)
        else:
            # Time delta between current timestamp and stored one should be calculated
            delta = int(script_exec_time - read_time)
            if delta >= crit:
                if options.verbose:
                    print_verbose_timestamps(script_exec_time, read_time, delta)
                print "CRITICAL. Counter %s wasn't changed since %s " % (options.name, pretty_time_format(read_time))
                sys.exit(EXIT_CRIT)
            if delta >= warn:
                if options.verbose:
                    print_verbose_timestamps(script_exec_time, read_time, delta)
                print "WARNING. Counter %s wasn't changed since %s " % (options.name, pretty_time_format(read_time))
                sys.exit(EXIT_WARN)
            else:
                if options.verbose:
                    print_verbose_timestamps(script_exec_time, read_time, delta)
                print "OK. Time Delta is within thresholds :: %s | %s | %s " % (delta, warn, crit)
                sys.exit(EXIT_OK)


def retrieve_counters_page(url, timeout_v=60):
    """ Function for downloading web page using generated URL """

    try:
        response = urllib2.urlopen(url, timeout=timeout_v).read()
    except (urllib2.URLError, urllib2.HTTPError) as err:
        print "URL : %s  cannot be retrieved due to %s " % (url, err)
        sys.exit(EXIT_CRIT)
    else:
        if options.verbose:
            print "Retrieving URL".center(80, '-')
            print "URL: %s " % url
            print "Retrieving URL".center(80, '-')

        return response

def get_needed_counter(arr, countername):
    """ Functions parses list of dictionaries and looks for
        specified counter's name.
        If not found exits with UNKNOWN """

    for i in xrange(len(arr)):
        if arr[i]['name'] == countername:
            if options.verbose:
                print "Counter %s found at index %s " % (countername, i)
            return arr[i]

    if options.verbose:
        print "FOUND NEXT COUNTERS".center(80, '-')
        print '\n'.join(arr[i]['name'] for i in xrange(len(arr)))
        print "FOUND NEXT COUNTERS".center(80, '-')

    print "No Matches found"
    sys.exit(EXIT_UNK)

def print_counter_pretty(counters_dict):
    """ Function to print counters in pretty way :) """

    for i in counters_dict.keys():
        print "%20s : %-40s" % (i, counters_dict[i])

def get_counter_value(counter_dict, item="value"):
    """ Function for getting counter's value """

    if item == 'rate_d'  or item == 'value':
        need =  'value'
        if counter_dict.has_key(need):
            counters_value = counter_dict[need]
            return counters_value
        else:
            print "UNKNOWN. Specified Attribute %s does not exist." % need
            sys.exit(EXIT_UNK)
    else:
        need = 'rate'
        if counter_dict.has_key(need):
            counters_value = counter_dict[need][0]
            return counters_value
        else:
            print "UNKNOWN. Specified Attribute %s does not exist." % need
            sys.exit(EXIT_UNK)

# --- MAIN PART

parser = OptionParser()

parser.add_option("-H", "--host", dest="host",
                        help="Hostname where to look for counters")
parser.add_option("-d", "--daemon", dest="daemon",
                        help="Could be either \"packager\" or \"publisher\" ")
parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                         default=False, help="Verbose output")
parser.add_option("-c", "--critical", type="float", dest="critical", default=0,
                        help="Critical threshold. Default = 0.")
parser.add_option("-w", "--warning", type="float", dest="warning", default=0,
                        help="Warning threshold. Default = 0.")
parser.add_option("-n", "--name", dest="name",
                        help="Counter's Name to check")
parser.add_option("-C", "--counter-page", dest="counterspage",
                        default = "/counters-json",
                        help="Page where to look for counters." +
                               "Default = /counters-json")
parser.add_option("-N", "--node-status", dest="nodestatuspage",
                        default = "/node_status",
                        help="Page with node status data. "  \
                             "  Default = /node_status")
parser.add_option("-t", "--type", dest="counterstype", default="value",
                        help="Type of Counter. Could be value or rate_d or rate_m")

options, args = parser.parse_args()

# Checking if all variables are OK

if options.daemon not in daemons_dict:
    print "Unsupportted Daemon %s " % options.daemon
    print "Supported daemons are ", \
           (','.join(i for i in sorted(daemons_dict.keys())))
    sys.exit(EXIT_UNK)

if options.host == '' or options.host == None:
    print "HOSTNAME is MANDATORY"
    sys.exit(EXIT_UNK)

if options.name == '' or options.name == None:
    print "Counter's name is MANDATORY"
    sys.exit(EXIT_UNK)

if options.counterstype not in counters_tuple:
    print "Unsupported Counter's Type : %s " % options.counterstype
    print "Supported are : %s " % (','.join(i for i in counters_tuple))
    sys.exit(EXIT_UNK)

# Generating Timestamp of script execution
script_exec_time = int(time.time())

# Generating file name
filename = gen_file_name(options.name)

node_url = generate_url(options.host, options.nodestatuspage)

response_base = retrieve_counters_page(node_url)
soup_base = BeautifulSoup(response_base)
table_list_base = get_tables(soup_base)
active_table_id = find_table_index_via_header(table_list_base, 'node_state')
found_url = parse_table_rows(table_list_base, active_table_id)

counter_url =  generate_url(found_url, options.counterspage)

response_counter_raw = retrieve_counters_page(counter_url)
response_counter = json.loads(response_counter_raw)

found_counter = get_needed_counter(response_counter, options.name)

if options.verbose:
    print "Pretty Formatting".center(80, '-')
    print_counter_pretty(found_counter)
    print "Pretty Formatting End".center(80, '-')
    retrieved_value_verbose = get_counter_value(found_counter, options.counterstype)
    print "Counter %s has value equal to %s " % (options.name, retrieved_value_verbose)

###############################################################################
# New Functions for reading/storing/comparing results                         #
###############################################################################

compare_values(options.counterstype, options.warning, options.critical)
