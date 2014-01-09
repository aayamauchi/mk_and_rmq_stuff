#!/bin/env python26

#Script to check hadoop cluster nodes state via http status page 
#Ticket: https://jira.sco.cisco.com/browse/MONOPS-1414
#Spec: http://eng.ironport.com/docs/is/ars/2_0/eng/monitoring_spec.rst#hadoop-related-general-monitors
#Author: Bogdan Berezovyi <bberezov@cisco.com>

import urllib2
import sys
from BeautifulSoup import BeautifulSoup
from optparse import OptionParser

# Default Nagios Exit Codes
EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

def verbose(s):
    if options.verbose:
        print s

def get_value(cols, attr):
	value = ''
	cols = [ i for i in cols if i.find('a') ]
	for i in cols:
		if attr in i.find('a')['href']:
			value = i.text
	if value:
		return int(value)
	else:
		print "UNKNOWN. Problem retrieving value for %s" % (attr)
		sys.exit(EXIT_UNK)

parser = OptionParser()

parser.add_option("-H", "--host", dest="host",
                        help="Hostname where to look for status page")
parser.add_option("-p", "--port", dest="port", default='50030',
                        help="Http port to check. Default = 50030")
parser.add_option("-u", "--url", dest="url", default='/jobtracker.jsp',
                        help="URL of the tracker. Default = '/jobtracker.jsp'")
parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                        default=False, help="Verbose output")
parser.add_option("-a", "--active", type="int", dest="tactive", default=40,
                        help="Active nodes threshold. Default = 40.")
parser.add_option("-b", "--black", type="int", dest="tblack", default=40,
                        help="Blacklisted nodes threshold. Default = 0.")
parser.add_option("-g", "--grey", type="int", dest="tgrey", default=40,
                        help="Greylisted nodes threshold. Default = 0.")
parser.add_option("-e", "--excl", type="int", dest="texcl", default=40,
                        help="Excluded nodes threshold. Default = 0.")

(options, args) = parser.parse_args()

if not options.host:
	 parser.error('Hostname not provided')

url = "http://" + options.host + ":" + options.port + options.url

try:
    verbose( "Downloading URL : %s " % url)
    page = urllib2.urlopen(url, timeout = 60).read()
except (urllib2.HTTPError, urllib2.URLError) as err:
    print "UNKNOWN. Problem retrieving data from %s. Error: %s " % (url, err)
    sys.exit(EXIT_UNK)

# converting retrieved page to BeautifulSoup format
verbose("Converting read data to SOUP format")

soup = BeautifulSoup(page)

verbose("Parsing Cluster summary table")

table = soup.find("table")
rows = table.findAll('tr')[1]
cols = rows.findAll('td')

active = get_value(cols, 'active')
blacklisted = get_value(cols, 'blacklisted')
greylisted = get_value(cols, 'graylisted')
excluded = get_value(cols, 'excluded')

verbose("Active: %s" %active)
verbose("Blacklisted: %s" %blacklisted)
verbose("Greylisted: %s" %greylisted)
verbose("Excluded: %s" %excluded)


if (active < options.tactive or blacklisted > options.tblack or greylisted > options.tgrey or excluded > options.texcl):
	print "CRITICAL: Active: %(active)s, Blacklisted: %(blacklisted)s, Greylisted: %(greylisted)s, Excluded: %(excluded)s" %locals()
	sys.exit(EXIT_CRIT)
else:
	print "OK: Active: %(active)s, Blacklisted: %(blacklisted)s, Greylisted: %(greylisted)s, Excluded: %(excluded)s" %locals()
	sys.exit(EXIT_OK)

