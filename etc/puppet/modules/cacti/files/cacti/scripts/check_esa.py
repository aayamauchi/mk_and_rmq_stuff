#!/usr/bin/python26

# IronPort ESA poller script
# Maintained by Mike Lindsey - mike@bettyscout.org
# v1.1, 1/10/2007
# Free for use for all purposes, please forward improvements
# back to the cacti community.

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

    socket.setdefaulttimeout(10)

    usage = "usage: %prog [options] host"
    opt_parser = optparse.OptionParser()
    opt_parser.add_option("-u", "--user", default="admin",
        help="User to authenticate as.  Default: admin")
    opt_parser.add_option("-p", "--passwd", default="",
        help="Password to authenticate with.")
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
        sys.exit(2)
    except IndexError:
        print "Error: No host provided."
        opt_parser.print_help()
        sys.exit(2)
    # STUPID TEMPORARY HACK
    # Built the graph templates incorrectly, need to totally rebuild them to
    # allow multiple ESA passwords.  - Mike Lindsey
    if (host.split('.')[2] == 'postx'):
        opt.passwd = 'formeonly46'
    elif ('iphmx' in host):
        opt.user = 'hosted_metrics'
        opt.passwd = '4e8dcaf44675638b94edb71b55cff577'

    url = "http://%s/xml/status" % (host)
    urls = "http://%s/xml/status" % (host)
    handler = urllib2.HTTPBasicAuthHandler()
    handler.add_password(opt.realm, host, opt.user, opt.passwd)
    opener = urllib2.build_opener(handler)
    urllib2.install_opener(opener)

    try:
        client = urllib2.urlopen(url)
    except urllib2.HTTPError:
        try:
            client = urllib2.urlopen(urls)
        except urllib2.HTTPError:
            print "Error: Problem opening url."
            traceback.print_exc()
            sys.exit(2)

    data = ''.join(client.readlines())
    dom = minidom.parseString(data)

    # Gather & print counter info.
    counter_group = dom.getElementsByTagName("counters")[0]
    counters = counter_group.getElementsByTagName("counter")
    for counter in counters:
	print "%s:%s" % ( counter.attributes["name"].value, counter.attributes["lifetime"].value ),

    # Now gather & print some guage info
    gauge_group = dom.getElementsByTagName("gauges")[0]
    gauges = gauge_group.getElementsByTagName("gauge")
    for gauge in gauges:
        if gauge.attributes["name"].value == "conn_in":
            print "conn_in:%s" % (
                gauge.attributes["current"].value),
        if gauge.attributes["name"].value == "conn_out":
            print "conn_out:%s" % (
                gauge.attributes["current"].value),
