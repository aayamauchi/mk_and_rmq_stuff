#!/usr/bin/python26

if __name__ == '__main__':
    import DNS
    import optparse
    import socket
    import time
    import sys

    usage = "%prog [options] host"
    opt_parser = optparse.OptionParser(usage=usage)
    opt_parser.add_option("-z", "--zone", default="rf.senderbase.org",
            help="Zone to query.")
    opt_parser.add_option("-w", "--warning", type="int",
        help="Warning threshold in seconds.")
    opt_parser.add_option("-c", "--critical", type="int",
        help="Critical threshold in seconds.")

    try:
        (options, args) = opt_parser.parse_args()
    except optparse.OptParseError:
        print "CRITICAL - Invalid commandline arguments."
        opt_parser.print_help()
        traceback.print_exc()
        sys.exit(2)

    try:
        host = args[0]
    except IndexError:
        print "No host specified."
        opt_parser.print_help()
        sys.exit(256)

    req = DNS.Request()

    try:
        execute_start = time.time()
        query = req.req(name="2.0.0.127." + options.zone,
            server=host,
            qtype="txt",
            timeout=5)
        response = query.answers[0]['data'][0]
        last_update = float(response.split('|')[10].split('=')[1])
        execute_time = time.time() - execute_start
        update_age = time.time() - last_update
    except (DNS.Base.DNSError, socket.error):
        print "CRITICAL - Could not contact server '%s'." % (host)

    if options.critical == None and options.warning == None:
        print "Zone %s was lasted updated %d seconds ago on server " \
            "%s." % (options.zone, update_age, host)

    if update_age > options.critical and not options.critical is None:
        print "CRITICAL - Zone %s was last updated %d seconds " \
            "ago." % (options.zone, update_age)
        sys.exit(2)

    if update_age > options.warning and not options.warning is None:
        print "WARNING - Zone %s was last updated %d seconds " \
            "ago." % (options.zone, update_age)
        sys.exit(1)

    print "OK - Zone %s was last updated %d seconds ago." % (
        options.zone, update_age)
