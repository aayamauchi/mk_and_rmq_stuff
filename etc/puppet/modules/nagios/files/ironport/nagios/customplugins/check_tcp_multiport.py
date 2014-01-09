#!/usr/bin/env python2.6

"""
Threaded Python multiple port scanner.
Analog of check_tcp but quickly checks multiple of ports which to be specified on the command line.

Usage: %s -H <server> [-w <warning>] [-c <critical>] -p \"<list of opened ports>\"

see MONOPS-1417 for details
author: vmashkov
"""

import threading
import socket
import time
import getopt
import sys
import re


def usage():
    print "Threaded Python multiple port scanner."
    print "Usage: %s -H <server> [-w <warning>] [-c <critical>] -p \"<list of opened ports>\"" % (sys.argv[0])


try:
    optlist, args = getopt.getopt(sys.argv[1:], 'H:w:c:p:h')
except getopt.GetoptError:
    usage()
    sys.exit(2)

# Standard exit codes; see http://nagiosplug.sourceforge.net/developer-guidelines.html
EXIT_OK = 0
EXIT_WARN = 1
EXIT_ERR = 2

# Default walues for time of response
warning = 10
critical = 30

if len(sys.argv) < 2:
    usage()
    sys.exit(2)

for opt, arg in optlist:
    if opt == '-h':
        usage()
        sys.exit(2)
    if opt == '-H':
        server = arg
    if opt == '-p':
        ports = arg
    if opt == '-w':
        warning = int(arg)
    if opt == '-c':
        critical = int(arg)

if ports == None or server == None:
    print "Server or ports not entered."
    usage()
    sys.exit(2)

# Set timeout ceiling (coincide with nagios max runtime)
if critical >= 60:
    critical = 58

# Set an absolute maximum timeout for socket connections
socket.setdefaulttimeout(critical)

def check_port(server,port):
    s = socket.socket()
    if s.connect_ex((server,port)) == 0:
        ports_opened.append(port)
    else:
        ports_closed.append(port)
    s.close()

s = time.time()
threads = []
ports_opened = []
ports_closed = []

p=re.compile('[,; \t\n\s]+')
try:
    ports = p.split(ports)
except:
    print "Can not parse list of ports for checking: %s" % (ports)

for port in ports:
    t = threading.Thread(target=check_port,args=(server,int(port)))
    t.start()
    threads.append(t)
for t in threads:
    t.join()

time_value = time.time() - s

if ports_closed:
    msg = "Opened ports: %s; not opened but expected %s."% (ports_opened, ports_closed)
    exit_code = EXIT_ERR
else:
    msg = "All ports %s opened." % (ports_opened)
    exit_code = EXIT_OK

if time_value > critical:
    msg += " Time is CRITICAL %s seconds." % (time_value)
    exit_code = EXIT_ERR
    print msg
    sys.exit(exit_code)


if time_value > warning:
    msg += " Time is warning %s seconds." % (time_value)
    if exit_code == EXIT_OK:
        exit_code = EXIT_WARN
    print "WARNING: ", msg
    sys.exit(exit_code)

if exit_code == 0:
    print "OK: ", msg
else:
    print "CRITICAL: ", msg

sys.exit(exit_code)
