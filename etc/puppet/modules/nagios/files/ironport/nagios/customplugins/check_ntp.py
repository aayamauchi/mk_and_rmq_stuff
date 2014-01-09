#!/usr/bin/python26
###########################################################
#                    Simple NTP Program                                                                           #
#                    By  Maxin B. John (www.linuxify.net)                                                #
#   Simple NTP Client program with command line option                                 #
###########################################################
# modified by Mike Lindsey <miklinds@ironport.com> 
# to be suitable for a nagios check script
from socket import *
import struct
import sys
import time as timemod
import os
from optparse import OptionParser

Server = ''
parser = OptionParser()
parser.add_option("-s","--server",dest="server",help="NTP server to contact, default 0.fedora.pool.ntp.org", default="0.fedora.pool.ntp.org")
parser.add_option("-o","--otherserver",dest="otherserver",help="Other NTP server to contact. Useful for comparing two NTP servers against eachother.  Otherwise the script compares the local time against the --server's time.")
parser.add_option("-c","--critical",dest="critical",type="float",help="critical threshold in seconds, default=10",default="10")
parser.add_option("-w","--warning",dest="warning",type="float",help="warning threshold in seconds, default=5",default="5")
(options,args) = parser.parse_args()

exit = 0
delta = None
try:
    data1 = os.popen('/usr/sbin/ntpdate -q %s 2>/dev/null' % (options.server)).read()
except:
    print 'Unable to run ntpdate against %s' % (options.server)
else:
    words1 = data1
    try:
        data1 = float(data1.split('offset ')[1].split(',')[0])
    except:
        print 'Unable to extract ntp offset from:\n %s' % (data1)
    else:
        delta = data1
if options.otherserver:
    try:
        data2 = os.popen('/usr/sbin/ntpdate -q %s 2>/dev/null' % (options.otherserver)).read()
    except:
        print 'Unable to run ntpdate against %s' % (options.otherserver)
    else:
        words2 = data2
        try:
            data2 = float(data2.split('offset ')[1].split(',')[0])
        except:
            print 'Unable to extract ntp offset from:\n %s' % (data2)
            delta = None
        else:
            if delta is not None:
                delta = data2 - delta

if delta is not None:
    try:
        delay1 = float(words1.split()[-1])
    except:
        pass
    else:
        if float(words1.split()[-1]) == 0:
            print "UNKNOWN ntp offset, cannot reach %s" % (options.server)
            sys.exit(3)
    try:
        delay2 = float(words2.split()[-1])
    except:
        pass
    else:
        if options.otherserver and float(words2.split()[-1]) == 0:
            print "UNKNOWN ntp offset, cannot reach %s" % (options.otherserver)
            sys.exit(3)
    if (abs(delta) >= options.critical):
        print "CRITICAL ntp offset %s seconds (%s - %s)" % (delta, data1, data2)
        sys.exit(2)
    if (abs(delta) >= options.warning):
        print "WARNING ntp offset %s seconds (%s - %s)" % (delta, data1, data2)
        sys.exit(1)
    print "OK ntp offset %s seconds (%s - %s)" % (delta, data1, data2)
    sys.exit(0)
else:
    sys.exit(3)
