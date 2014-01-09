#!/bin/env python26

# Script created by Iurii Prokulevych
# per ticket MONOPS-1324
# Checks which runbook's name should be used

# defining tuple of services
runbooks_dict = {'whiskey_local_crons-sa_updater-':'whiskey_local_crons-sa_updater'}
import sys

EXIT_OK = 0
EXIT_WARN = 1
EXIT_CRIT = 2
EXIT_UNK = 3

try:
    service = sys.argv[1]
except IndexError:
    print "[https://confluence.sco.cisco.com/display/public/KB/Knowledge+Base+Home]"
    sys.exit(EXIT_UNK)
else:
    for i in sorted(runbooks_dict.keys()):
        if service.startswith(i):
            print " [https://confluence.sco.cisco.com/display/KB/RUN:%s]" % (runbooks_dict[i])
            sys.exit(EXIT_OK)
    # Return passed service's name if nothing is found in services_tuple list
    print " [https://confluence.sco.cisco.com/display/KB/RUN:%s]" % (service)
    sys.exit(EXIT_OK)
