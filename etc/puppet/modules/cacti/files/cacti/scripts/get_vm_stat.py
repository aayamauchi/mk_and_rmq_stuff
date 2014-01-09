#!/bin/env python26

import os
import sys
from pickle import loads

cache_dir = '/tmp/vmware_cache'
if len(sys.argv) < 3:
    print "%s <hostname> <stat>" % (sys.argv[0])
    sys.exit(3)

try:
    f = open('%s/vmpy__%s' % (cache_dir, sys.argv[1]))
except:
    print "Error: Unable to read cache file for %s" % (sys.argv[1])
    sys.exit(3)

try:
    stats = loads(f.read())
except:
    print "Error: Unable to read and depickle cached stats."
    sys.exit(3)

if sys.argv[2] == 'all':
    from pprint import pprint
    pprint(stats)
else:
    stat = []
    for arg in sys.argv[2:]:
        stat.append(arg)
        try:
            stats = stats[arg]
        except:
            print "Error: Unable to find stat %s in %s dict." % (','.join(stat), sys.argv[1])
            sys.exit(3)
    print stats
