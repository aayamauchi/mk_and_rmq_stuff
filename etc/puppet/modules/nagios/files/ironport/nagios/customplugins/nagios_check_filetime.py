#!/usr/bin/python26

import os, stat, sys, time, types, getopt

currentTime = int(time.time())

def syntax():
    print "syntax: %s -f <file> -w <seconds> [-c <seconds>] [-h]" % (sys.argv[0])
    print "   -f - file to be monitored"
    print "   -w - seconds till warning is thrown"
    print "   -c - seconds till critical is thrown, defaults to 2* warning"

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'f:w:c:h')
except getopt.GetoptError, inst:
    print inst
    syntax()
    sys.exit(2)

file = None
warningTime = None
criticalTime = None

for opt, arg in optlist:
    if opt == '-h':
        syntax()
        sys.exit(2)
    if opt == '-f':
        file = arg
    if opt == '-w':
        warningTime = int(arg)
    if opt == '-c':
        criticalTime = int(arg)

if not ( file and warningTime ):
    print "Missing switch."
    syntax()
    sys.exit(2)

file = time.strftime(file)

if not criticalTime: criticalTime = warningTime * 2

try:
    mtime = os.stat(file)[stat.ST_MTIME]
except OSError, (errnum, errstr):
    if errnum == 2:
        print "CRITICAL - File %s not found." % (file)
        sys.exit(2)
    else:
        raise OSError, errnum

drift = currentTime - mtime

if drift > criticalTime:
    print "CRITICAL - File %s not modified in %d seconds." % (file, drift)
    sys.exit(2)

if drift > warningTime:
    print "WARNING - File %s not modified in %d seconds." % (file, drift)
    sys.exit(1)

print "OK - File %s was modified %d seconds ago." % (file, drift)
