#!/bin/env python2.6

# Script created by Iurii Prokulevych per ticket MONOPS-1973
# Script checks if data between <display_version> tags is valid

import urllib2
import re
import sys
import random
import json
import pickle
import os
import time
import logging
import xml.etree.ElementTree as ET
import xml.parsers

from optparse import OptionParser

EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK =3

#--------------------------------CREATING LOGGER---------------------------------
logger = logging.getLogger("Default")
logger.setLevel(logging.NOTSET)

# Predefined Logging levels
LEVELS = { 'debug' : logging.DEBUG,
           'info'  : logging.INFO,
           'warning' : logging.WARNING,
           'critical' : logging.CRITICAL,
           'notset'   : logging.NOTSET}

#Creating formatter
formatter = logging.Formatter('[%(levelname)s %(asctime)s]: %(message)s')

#creating console handlers and setting level to DEBUG
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)

# adding formatter
ch.setFormatter(formatter)

# addging handler
logger.addHandler(ch)
#------------------------------CREATING LOGGER END-------------------------------

def check_file_exist(ffile):
    """ Function checks if  file does exist """

    logger.debug("Function check_file_exist() is called".center(80,'-'))
    if os.path.exists(ffile):
        logger.info("CACHE-FILE %s does exist" % ffile)
        logger.debug("Function check_file_exist() returns 'TRUE'")
        return True
    else:
        logger.info("CACHE-FILE %s does not exist" % ffile)
        logger.debug("Function check_file_exist() returns 'FALSE'")
        return False

def check_freshness(ffile, freshness):
    """ Function checks file's CTIME and compares it to now()
        If difference greater than freshness query ASDB """

    logger.debug("Function check_freshness() is called".center(80,'-'))
    query_db = False
    now = int(time.time())
    if check_file_exist(ffile):
        f_ctime = int(os.path.getctime(ffile))
    else:
        logger.info("CACHE-FILE %s not found. 1st run ?" % ffile)
        logger.debug("Function check_freshness() returns 'TRUE'")
        query_db = True
        return query_db

    delta = (now - f_ctime)
    if delta >= int(freshness):
        logger.info("CACHE-FILE %s has to be updated" % ffile)
        logger.debug("Function check_freshness() returns 'TRUE'")
        query_db = True
    else:
        logger.info("CACHE-FILE %s is fresh :) " % ffile)
        logger.info("CACHE-FILE %s was created %d seconds ago" % (ffile, delta))
        logger.debug("Function check_freshness() returns 'FALSE'")
        query_db = False

    return query_db

def get_host_list(fproduct, fenv, fpurpose, ffile):
    """Function to gather hosts from ASDB.
       Search criteria - Product, Environment, Purpose
       Returns JSON object with hosts metadata
       Data is also written to cache file  """

    logger.debug("Function get_host_list() is called".center(80, '-'))
    logger.info("Generating URL to request data from ASDB")
    asdb_url = "https://asdb.ironport.com/servers/data/?format=json"
    url = asdb_url + "&product__name=%s&environment__name=%s&purpose__name=%s" % (fproduct, fenv, fpurpose)
    logger.debug("Generated URL - %s " % url)

    hosts = retrieve_data_url(url)
    logger.info("Trying to dump data to CACHE-FILE %s " % ffile)
    try:
        tmp_f = open(ffile,'w')
    except IOError as err_msg:

        logger.critical("EXCEPTION".center(80, '-'))
        logger.critical(err_msg)
        logger.critical("EXCEPTION".center(80, '-'))
        logger.critical("Data cannot be written to  %s" % ffile)
        logger.warning("File %s will be removed (if exists) " % ffile)

        if os.path.exists(ffile) and os.path.isabs(ffile):
            os.remove(ffile)

        #Not paranoid, just to be sure
        if os.path.exists(ffile):
            logger.critical("FILE WAS NOT REMOVED".center(80,'-'))
    else:
        logger.info("CACHE-FILE %s was opened and it's status is %s " % (ffile, tmp_f))
        pickle.dump(hosts,tmp_f)
        tmp_f.close()
        logger.info("Data was dumped to file %s " % ffile)

    try:
        logger.debug("Trying to serialize data into the JSON format")
        hosts = json.loads(hosts)
    except ValueError, err_msg:
        logger.critical("EXCEPTION".center(80, '-'))
        logger.critical("Exception %s" % err_msg)
        logger.critical("EXCEPTION".center(80, '-'))
        logger.debug("Assigning empty list for hosts")
        hosts = []

    return hosts


def generate_url(fname, fserial, fversion):
    """ Function picks up random host from provided list.
        Based on chosen host generates URL to retrieve data from.
        If no data passed exits with UNKNOWN code """

    logger.debug("Function chose_random_host() is called".center(80, '-'))

    url = 'http://%s/cgi-bin/local_manifest.cgi?serial=%s&version=%s&type=manifest' % (fname, fserial, fversion)

    logger.debug("Generated URL - %s " % url)

    return url

def chose_host(jfile):
    """ Function parses file in JSON format and randomly chose hostname """

    if not len(jfile):
        print "UNKNOWN. Passed element has length 0(zero)."
        sys.exit(EXIT_UNK)
    else:
        # Additional validation is needed
        if len(jfile) == 1:
            logger.info('JSON object has lengt - %d' % len(jfile))
            jhost = str(jfile[0]['name'])
        else:
            try:
                logger.info('JSON object has length %d' % len(jfile))
                jhost = str(jfile[random.randint(0,len(jfile)-1)]['name'])
            except IndexError as err_msg:
                print "UNKNOWN. IndexError"
                print "EXCEPTION".center(80, '-')
                print err_msg
                print "EXCEPTION".center(80, '-')
                sys.exit(EXIT_UNK)

    return jhost


def load_host_list(ffile, fserial, fversion):
    """ Function loads data from file and serializes it to JSON.
        Returns URL to retieve data from"""

    logger.debug("Function load_host_list() is called".center(80,'-'))
    if check_file_exist(ffile):
        try:
            logger.debug("Trying to open %s" % ffile)
            tmp_f = open(ffile, 'r')
        except IOError as err_msg:
            print "UNKNOWN. Cannot read data from CACHE-FILE %s " % ffile
            print "EXCEPTION".center(80, '-')
            print err_msg
            print "EXCEPTION".center(80, '-')
            sys.exit(EXIT_UNK)
        else:
            logger.debug("Loading data from CACHE-FILE")
            obj = pickle.load(tmp_f)
            try:
                logger.debug("Trying to serialize data in JSON format")
                hosts = json.loads(obj)
            except ValueError, err_msg:
                print "UNKNOWN. Cannot get JSON from %s cachefile" % ffile
                print "EXCEPTION".center(80, '-')
                print "Exception %s" % err_msg
                print "EXCEPTION".center(80, '-')
                print "EXITING with UNKNONW state..."
                sys.exit(EXIT_UNK)
            else:
                hname = chose_host(hosts)
                rurl = generate_url(hname, fserial, fversion)
            return rurl

def parse_xml(response):
    """ Function parses response from server, converts it to XML and parse
        Returns list of complaining components """

    logger.debug("Function parse_xml() is called".center(80, '-'))

    try:
        logger.debug("Trying to parse XML from string")
        root = ET.fromstring(response)
    except (xml.parsers.expat.ExpatError, xml.parsers.expat.error) as err_msg:
        print "UNKNOWN. Cannot parse XML file"
        print "EXCEPTION".center(80, '-')
        print err_msg
        print "EXCEPTION".center(80, '-')
        print "EXITING with UNKNOWN state"
        sys.exit(EXIT_UNK)

    logger.debug("Compiling RegExp")
    pattern = re.compile('^AsyncOS (\d(.)*)+ [a-zA-Z\ 0-9]+')
    err_list = []

    for app in root.getiterator('application'):
        app_name = app.get('name')
        app_vers = app.get('version')
        logger.info("Checking Application '%s' - '%s'" % (app_name, app_vers))

        for i in app.findall('components/component'):
            comp_name = i.get('name')
            comp_env = i.get('environment_version')
            logger.info("Checking component %s" % comp_name)

            for j in i.findall('files/file/display_version'):
                if pattern.search(j.text):
                    logger.debug("display_version matched regexp - %s" % j.text)
                else:
                    err_msg = "Application Name - %s ; Application Version - %s ;" % ( app_name, app_vers )
                    err_msg += "Component Name - %s ; Component Environment - %s " % ( comp_name, comp_env )
                    err_msg += "contains invalid data %s " % (j.text )
                    err_list.append(str(err_msg))

    return err_list

def retrieve_data_url(furl):
    """ Function retrieves data from provided URL """

    logger.debug("Function retrieve_data_url() is called".center(80,'-'))
    try:
        logger.debug("Accessing URL")
        response =  urllib2.urlopen(furl).read()
    except (urllib2.URLError, urllib2.HTTPError) as err_msg:
        print "UNKNOWN. Cannot retrieve data from %s" % (rurl)
        print "EXCEPTION".center(80, '-')
        print err_msg
        print "EXCEPTION".center(80, '-')
        sys.exit(EXIT_UNK)
    else:
        logger.info("Data successfully retrieved from URL")
        return response


#-----------------------------------MAIN PART------------------------------------
parser = OptionParser()

parser.add_option("-P", "--product", dest="product",
                        help="PRODUCT to query servers from ASDB for. Mandatory")
parser.add_option("-p", "--purpose", dest="purpose",
                        help="PURPOSE of servers that are queried from ASDB. Mandatory")
parser.add_option("-e", "--environment", dest="env",
                        help="Servers environment. Mandatory")
parser.add_option("-c", "--cache-file", dest="cachefile",
                        help="Location of file for ASDB cache. Must be absolute path. Mandatory")
parser.add_option("-f", "--freshness", dest="freshness", type="int",default='3600',
                        help="Freshness threshold (seconds) for cache file. Default set - 3600")
parser.add_option("-s", "--serial", dest="serial",default="001C23C6017F-5JM9SD1",
                        help="Serial number for URL. Default set")
parser.add_option("-V", "--version", dest="version", default="phoebe-6-5-0-405",
                        help="Version for URL. Default set")
parser.add_option("-l", "--log-level", dest="loglevel", default="notset",
                        help="Verbosity Level. Default NOTSET")

options, args = parser.parse_args()

env_list = ['beta','dead','dev','inactive','int','Inventory Management', 'it','netops','new','ops','prod','qa','retired','stage','test','UNKNOWN']

purpose_list = ['app','dbm','dbs','www','wwwvip','vip']


#------------------------------VALIDATING ARGUMENTS------------------------------
if options.product is None or options.product == '':
    print "PRODUCT name is mandatory"
    sys.exit(EXIT_UNK)

if options.purpose is None or options.purpose == '':
    print "PURPOSE is mandatory"
    sys.exit(EXIT_UNK)
else:
    if options.purpose not in purpose_list:
        print "Invalid value %s for PURPOSE"
        sys.exit(EXIT_UNK)

if options.env is None or options.purpose == '':
    print "ENVRIONMENT is mandatory"
    sys.exit(EXIT_UNK)
else:
    if options.env not in env_list:
        print "Invalid value %s for ENVIRONMENT" % options.env
        sys.exit(EXIT_UNK)

if options.cachefile is None or options.cachefile == '':
    print "Please provide path to CACHE-FILE"
    sys.exit(EXIT_UNK)
else:
    if not os.path.isabs(options.cachefile):
        print "Path to CACHE-FILE must be absolute"
        sys.exit(EXIT_UNK)

if options.freshness is None or options.freshness == '':
    print "Please provide FRESHNESS threshold"
    sys.exit(EXIT_UNK)

if options.serial is None or options.serial == '':
    print "Pleae provide SERIAL"
    sys.exit(EXIT_UNK)

if options.version is None or options.version == '':
    print "Please provide VERSION"
    sys.exit(EXIT_UNK)

if options.loglevel is None or options.loglevel == '':
    print "Log Level cannot be empty"
    sys.exit(EXIT_UNK)
else:
    if options.loglevel.lower() not in LEVELS.keys():
        print "Provided value %s in not valid for Log Level" % options.loglevel
        print "Valid options are %s" % LEVELS.keys()
        sys.exit(EXIT_UNK)
    else:
        ll = LEVELS.get(options.loglevel)
        logger.setLevel(ll)
        logger.info("Level changed to %s" % options.loglevel)

if check_freshness(options.cachefile, options.freshness):
    host_list = get_host_list(options.product, options.env, options.purpose, options.cachefile)
    hname = chose_host(host_list)
    rurl = generate_url(hname, options.serial, options.version)

    retrieved_data = retrieve_data_url(rurl)
    err_list = parse_xml(retrieved_data)

else:
    logger.info("Trying to get data from CACHEFILE %s " % options.cachefile)
    rurl = load_host_list(options.cachefile, options.serial, options.version)

    retrieved_data = retrieve_data_url(rurl)
    err_list = parse_xml(retrieved_data)

if err_list:
    print "Critical. Data for display_version parameter is incorrect"
    print "\n".join(i for i in err_list)
    sys.exit(EXIT_CRIT)
else:
    print "OK.Data for display_version parameter is correct for all components"
    sys.exit(EXIT_OK)
