#!/usr/bin/python26

# -*- coding: ascii -*-

# Connects to Updates database, gets most recent released update,
# pretends to be c601 and downloads the update, then inspects it.
# Mike "Shaun" Lindsey <miklinds@ironport.com> 2/19/2009

import base64
import os
import socket
import sys
import traceback
import time
import MySQLdb
import _mysql_exceptions
import re
import urllib2
import zipfile
import StringIO
import xml.parsers.expat

from optparse import OptionParser


def getcode(addinfourl):
    """Get HTTP return code in a python library version independent way"""
    if hasattr(addinfourl, 'code'):
        return addinfourl.code
    return addinfourl.getcode()


def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name


def init():
    # collect option information, display help text if needed, set up debugging
    usage = """usage %prog [options]
Grabs the latest version from the updater database, then passes that string
and a serial number for c601 to the updates www vip, downloads the update,
unzips it and does light inspection."""
    parser = OptionParser(usage)
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="MySQL host to connect to.")
    parser.add_option("-d", "--db", type="string", dest="db",
                            help="Database to connect to. default='updater'",
                            default='updater')
    parser.add_option("-u", "--user", type="string", dest="user",
                            help="MySQL user to connect as.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="MySQL password to use.")
    parser.add_option("-U", "--url", type="string", dest="url",
                            help="Updates WWW vip to hit.")
    parser.add_option("-s", "--serial", type="string", dest="serial",
                            help="Serial to use for update grabbing. " \
                            "default='001EC94D1A2D-8P90PG1'",
                            default="001EC94D1A2D-8P90PG1")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    global options
    (options, args) = parser.parse_args()
    exitflag = 0
    if not options.user:
        exitflag = 1
        print "--user is not optional"
    if not options.password:
        exitflag = 1
        print "--password is not optional"
    if exitflag > 0:
        print
        parser.print_help()
        sys.exit(3)
    if options.verbose:
        sys.stderr.write(">>DEBUG sys.argv[0] running in debug mode\n")
    if options.verbose:
        sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    if options.verbose:
        sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")

    return options


def init_db():
    if options.verbose:
        sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    if options.verbose:
        sys.stderr.write("Connecting to %s\n" % (options.host))
    try:
        conn = MySQLdb.connect(host=options.host,
                               user=options.user,
                               passwd=options.password,
                               db=options.db)
    except (Exception,), e:
        print "MySQL connect error"
        sys.exit(exit['unkn'])
    if options.verbose:
        sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")
    return conn


def do_sql(sql):
    if options.verbose:
        sys.stderr.write(">>DEBUG start - " + funcname() + "()\n")
    conn = init_db()
    cursor = conn.cursor()
    if options.verbose:
        print "%s, %s" % (sql, conn)

    cursor.execute(sql)
    val = cursor.fetchall()
    if options.verbose:
        print "Results: %s" % (val)
    conn.commit()
    conn.close()
    if options.verbose:
        sys.stderr.write(">>DEBUG end    - " + funcname() + "()\n")
    return val


# 3 handler functions
def start_element(name, attrs):
    global element
    element = name


def char_data(data):
    data = data.strip('\n').strip('\t')
    if element == 'path' and data != '':
        global pathlist
        pathlist.append(data)


init()

# Hit the database and grab the version string for the most recent released
# update
try:
    #version = do_sql("""SELECT version_info.version FROM version_info """ \
    #WHERE version LIKE 'phoebe-%-%-%' AND released='yes' ORDER BY """ \
    #"""version DESC LIMIT 1""")[0][0]
    row = do_sql("""SELECT applications.version, groups_to_os.os_version
FROM applications
INNER JOIN packages ON packages.app_id = applications.id
INNER JOIN groups_to_packages ON groups_to_packages.package_id = packages.id
INNER JOIN groups ON groups.id = groups_to_packages.group_id
INNER JOIN groups_to_os ON groups_to_os.group_id = groups.id
INNER JOIN groups_to_serials ON groups_to_serials.group_id = groups.id
WHERE applications.version LIKE 'phoebe-_-_-_-___'
AND groups_to_serials.serial = "%s"
ORDER BY applications.version DESC
LIMIT 1
""" % (options.serial,))[0]
    (to_build, from_build) = row
# Um, probably not going to raise ZipFile exceptions here...
except (zipfile.BadZipfile,), e:
    print "Unknown MySQL connection or select error."
    if options.verbose:
        sys.stderr.write(">>DEBUG BadZipfile exception " + repr(e))
    sys.exit(3)

url = "http://%s/cgi-bin/local_manifest.cgi?&serial=%s&version=%s&to_build=" \
        "%s&type=image" % (options.url, options.serial, from_build, to_build)
if options.verbose:
    print "URL is %s" % (url)

# Set up in-memory file object
try:
    zipfh = StringIO.StringIO()
except Exception, e:
    print "File access error for virtual file!"
    if options.verbose:
        sys.stderr.write(">>DEBUG Exception " + repr(e))
    sys.exit(3)

# Download image and shove in the memory object
req = urllib2.Request(url)
try:
    http_connection = urllib2.urlopen(url)
    code = getcode(http_connection)
    if code >= 400:
        print "Server returned a %d code trying to access %s" % (code, url)
        sys.exit(2)
    zipfh.write(http_connection.read())
except (Exception,), e:
    print "Error grabbing image from %s : %s" % (url, e)
    sys.exit(2)

zipfh.seek(0)

# Convert to zipfile object, and test integrity.
try:
    zipfh = zipfile.ZipFile(zipfh)
except (Exception,), e:
    print "Did not get a zipfile for version %s from www server." % (to_build)
    if options.verbose:
        sys.stderr.write(">>DEBUG Exception " + repr(e))
    sys.exit(2)
if zipfh.testzip():
    print "Error with zipfile, cannot unzip."
    sys.exit(2)

# Extract xmlfile to memory.
try:
    xmlfile = zipfh.read('asyncos/%s.xml' % (to_build))
except (Exception,), e:
    if options.verbose:
        sys.stderr.write(">>DEBUG Exception " + repr(e))
    print "Unable to find xml file (%s) inside image." % ('asyncos/%s.xml' %
                                                          (to_build))
    sys.exit(2)

# Initiate handlers, to store data we care about validating
xmlp = xml.parsers.expat.ParserCreate()
xmlp.StartElementHandler = start_element
xmlp.CharacterDataHandler = char_data

pathlist = []
element = ''

# Parse xml for errors.
try:
    xmlp.Parse(xmlfile, True)
except (Exception,), e:
    print "Error parsing XML"
    if options.verbose:
        sys.stderr.write(">>DEBUG Exception " + repr(e))
    sys.exit(2)

# Validate filenames from the xml, against filelist in zipfile.
for file in pathlist:
    if file not in zipfh.namelist():
        print "File (%s) in xml not found in zip!"
        sys.exit(2)

print "Update %s appears to be valid." % (to_build)
sys.exit(0)
