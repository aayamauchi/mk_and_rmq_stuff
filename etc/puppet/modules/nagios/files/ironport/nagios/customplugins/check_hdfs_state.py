#!/bin/env python26

#Script to parse HDFS status page
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

criticals = []

def verbose(s):
    if options.verbose:
        print s

def get_value(data, attr):
	value = ''
	tag = data.find(text='%s' %attr).findParent()
	value = tag.findNext().findNext().text
	if value:
		return value
	else:
		print "UNKNOWN. Problem retrieving value for %s" % (attr)
		sys.exit(EXIT_UNK)

parser = OptionParser()

parser.add_option("-H", "--host", dest="host",
                        help="Hostname where to look for status page")
parser.add_option("-p", "--port", dest="port", default='50070',
                        help="Http port to check. Default = 50070")
parser.add_option("-u", "--url", dest="url", default='/dfshealth.jsp',
                        help="URL of the tracker. Default = '/dfshealth.jsp'")
parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                        default=False, help="Verbose output")
parser.add_option("-l", "--live", type="int", dest="tlive", default=90,
                        help="Live nodes threshold as percent to all nodes. Default = 90.")
parser.add_option("-d", "--dfs", type="int", dest="dfs", default=10,
                        help="DFS Remaining threshold, percents. Default = 10.")

(options, args) = parser.parse_args()

if not options.host:
	 parser.error('Hostname not provided')

url = "http://" + options.host + ":" + options.port + options.url

try:
    verbose( "Downloading URL : %s " % url)
    page = urllib2.urlopen(url).read()
except (urllib2.HTTPError, urllib2.URLError) as err:
    print "UNKNOWN. Problem retrieving data from %s. Error: %s " % (url, err)
    sys.exit(EXIT_UNK)

# converting retrieved page to BeautifulSoup format
verbose("Converting read data to SOUP format")

soup = BeautifulSoup(page)

verbose("Parsing html")

table=soup.findAll("table")[1]

live = int(get_value(table, 'Live Nodes'))
decom = int(get_value(table, 'Decommissioning Nodes'))
dead = int(get_value(table, 'Dead Nodes'))
dfs_ramain = get_value(table, ' DFS Remaining%')
dfs_ramain = float(dfs_ramain.strip(' \t\n\r%'))

percent_live = (live / float(live + decom + dead))*100


verbose("Live: %s" %live)
verbose("Decommissioning: %s" %decom)
verbose("Dead: %s" %dead)
verbose("DFS Remaining %%: %s" %dfs_ramain)

verbose("Percent Live %%: %.2f" %percent_live)

if percent_live <= options.tlive:
	text = "Percent of Active Nodes is %.2f %% (CRITICAL: %s %%)" %(percent_live,options.tlive)
	criticals.append(text)
if dfs_ramain <= options.dfs:
	text = "DFS Remaining: %s %% (CRITICAL: %s %%)" %(dfs_ramain,options.dfs)
	criticals.append(text)


if criticals:
	print "CRITICAL - ",
	print ", ".join(criticals)
	sys.exit(EXIT_CRIT)
else:
	print "OK: Live: %(live)s, Decommissioning: %(decom)s, Dead: %(dead)s, DFS Remaining: %(dfs_ramain)s %%" %locals()
	sys.exit(EXIT_OK)

