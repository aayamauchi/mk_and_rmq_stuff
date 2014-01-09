#!/usr/bin/python26
"""Script to read in /etc/passwd and check for formatting errors"""

import sys
import shlex
import subprocess
from subprocess import PIPE, STDOUT

if __name__ == '__main__':
    script = '%s/ldap-pwgen.py %s/centralizedauth.cfg' % (sys.path[0], sys.path[0])
    try:
        passwd = subprocess.Popen(shlex.split(script), stdout=PIPE, stderr=STDOUT)
    except OSError:
        print "Can't run ldap-pwgen file for validation."
        sys.exit(3)

    lines = passwd.stdout.readlines()

    seen = []
    error = 0

    print "LDAP-pwgen validation:",

    for line in lines:
        line = line.strip().split(':')
        if line[0] in seen:
            print "Duplicate entry for %s" % (line[0])
            error = 2
        seen.append(line[0])
        if len(line) != 10:
            print "Inappropriate field count (%s) for %s" % (len(line), line[0])
            error = 2
        if not len(line[1]):
            print "No password set for %s" % (line[0])
            error = 2
    if len(lines) < 500:
        print "Unexpected reduction in passwd entries (%s)" % (len(lines))
        error = 2
    if len(lines) > 1000:
        print "Unexpected jump in passwd entries (%s)" % (len(lines))
        if not error:
            error = 1

    if not error:
        print "Passwd validation successful."
    sys.exit(error)
