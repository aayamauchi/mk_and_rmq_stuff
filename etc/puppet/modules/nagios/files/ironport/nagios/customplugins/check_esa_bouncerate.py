#!/usr/bin/env python26
#==============================================================================
# check_esa_bouncerate.py
#
# Most of this was borrowed from the cacti script, cacti_check_esa.py,
# and modified to grab rates instead of counters - in particular bounce rates.
#
# A note about bounce rates on the xml status page of eash esa:
# https://HOSTNAME/xml/status
# These are rates per hour, taken in increments of 1, 5, 15 minutes.
# To convert the rate to an approximate count for the 5 minute window,
# you always divide the value by 12 (so 12/12 would be 1 bounce, etc...).
# This script only cares about the 5 minute window (last_5_min).
#
# 2011-05-19 jramache
#==============================================================================
if __name__ == '__main__':
    import urllib2
    import sys
    import getopt
    import time
    import getpass
    from xml.dom import minidom
    import traceback
    import optparse
    import socket
    import re

    socket.setdefaulttimeout(5)

    nagios_states = {'ok': 0, 'warning': 1, 'critical': 2, 'unknown': 3}
    exit_code = nagios_states['unknown']
    exit_info = "Unable to determine bounce rates"

    usage = "usage: %prog [options] host"
    opt_parser = optparse.OptionParser()
    opt_parser.add_option("-u", "--user", default="admin",
        help="User to authenticate as.  Default: admin")
    opt_parser.add_option("-p", "--passwd", default="",
        help="Password to authenticate with.")
    opt_parser.add_option("-t", "--type", default="",
        help="Bounce type: hard, soft, or combined.")
    opt_parser.add_option("-w", "--warning", type="int", 
        help="Warning threshold")
    opt_parser.add_option("-c", "--critical", type="int", 
        help="Critical threshold")
    opt_parser.add_option("-r", "--realm", default="IronPort Web Interface",
            help="HTTP Realm to authenticate in.  Defaults to: " \
                 "IronPort Web Interface")

    try:
        (opt, args) = opt_parser.parse_args()
        host = args[0]
    except optparse.OptParseError:
        print "Error: Invalid command line parameters."
        opt_parser.print_help()
        traceback.print_exc()
        sys.exit(3)
    except IndexError:
        print "Error: No host provided."
        opt_parser.print_help()
        sys.exit(3)

    if ((opt.type != 'combined') and (opt.type != 'hard') and (opt.type != 'soft')):
        print "Error: missing a valid bounce type specifier"
        opt.parser.print_help()
        sys.exit(exit_code)

    if ((not opt.warning) or (not opt.critical)):
        print "Error: warning and critical thresholds are both required"
        sys.exit(exit_code)

    if (opt.warning >= opt.critical):
        print "Error: warning threshold must be lower than critical threshold"
        sys.exit(exit_code)

    url = "http://%s/xml/status" % (host)
    handler = urllib2.HTTPBasicAuthHandler()
    handler.add_password(opt.realm, host, opt.user, opt.passwd)
    opener = urllib2.build_opener(handler)
    urllib2.install_opener(opener)

    try:
        client = urllib2.urlopen(url)
    except urllib2.HTTPError:
        print "Error: Problem opening url."
        traceback.print_exc()
        sys.exit(2)

    data = ''.join(client.readlines())
    dom = minidom.parseString(data)

    # Gather rate info
    bouncerate = 0
    rate_group = dom.getElementsByTagName("rates")[0]
    rates = rate_group.getElementsByTagName("rate")
    for rate in rates:
        rate_name = rate.attributes["name"].value
        if (rate_name == 'soft_bounced_evts') or (rate_name == 'hard_bounced_recips'):
            if (opt.type == 'combined'):
                bouncerate += int(rate.attributes["last_5_min"].value)
            elif (opt.type == 'soft') and (rate_name == 'soft_bounced_evts'):
                bouncerate += int(rate.attributes["last_5_min"].value)
            elif (opt.type == 'hard') and (rate_name == 'hard_bounced_recips'):
                bouncerate += int(rate.attributes["last_5_min"].value)

    if (bouncerate > opt.critical):
        exit_code = nagios_states['critical']
    elif (bouncerate > opt.warning):
        exit_code = nagios_states['warning']
    else:
        exit_code = nagios_states['ok']

    bouncerate_units = "bounces"
    if bouncerate == 1:
        bouncerate_units = "bounce"

    bouncecount = int((float(bouncerate)/12.0) + 0.5)
    bouncecount_units = "bounces"
    if bouncecount == 1:
        bouncecount_units = "bounce"

    exit_info = "%d %s/hour (%d actual %s) in the past 5 minutes" % (bouncerate, bouncerate_units, bouncecount, bouncecount_units)

exit_state = 'unknown'
for s in nagios_states.keys():
    if nagios_states[s] == exit_code:
        exit_state = s
print "%s - %s" % (exit_state.upper(), exit_info)
sys.exit(exit_code)
