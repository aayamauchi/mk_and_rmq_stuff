#!/usr/bin/python26

if __name__ == '__main__':
    import urllib2
    import sys
    import os
    import stat
    import getopt
    import time
    import getpass
    import pickle
    import nagiosplugin
    from xml.dom import minidom
    import traceback
    import optparse
    import socket

    socket.setdefaulttimeout(2)

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
    elif ('smtpi' in host):
        opt.user = 'hosted_metrics'
        opt.passwd = 'f818aef0090e16f0be2ab80cc2eb55a2'

    cookiefile = '/usr/local/nagios/var/tmp/npcookie.asyncos.%s' % (host)
    if not os.path.exists(cookiefile):
        cookiefile = '/tmp/npcookie.asyncos.%s' % (host)
    cookie = nagiosplugin.Cookie(cookiefile)
    data = cookie.get()
    cookie.close()
    if data is None:
        data = {}
    else:
        data = pickle.loads(data)
    if len(data.keys()):
        first = sorted(data.keys())[0]
        last = sorted(data.keys())[-1]
    else:
        first = 0
        last = 0

    if last + 120 < time.time():

        url = "https://%s/xml/status" % (host)
        url2 = "http://%s/xml/status" % (host)
        handler = urllib2.HTTPBasicAuthHandler()
        handler.add_password(opt.realm, host, opt.user, opt.passwd)
        opener = urllib2.build_opener(handler)
        urllib2.install_opener(opener)

        try:
            client = urllib2.urlopen(url)
        except:
            client = urllib2.urlopen(url2)
            proto = 'http'
        else:
            proto = 'https'

        datum = ''.join(client.readlines())
        # Only keep five items in the cache.
        if len(data) > 4:
            del data[first]
            first = sorted(data.keys())[0]
        outurl = '%s://%s/login?action=Logout' % (proto, host)
        try:
            urllib2.urlopen(outurl).close()
        except:
            # 'Error closing logout.'
            pass
        client.close()
        opener.close()

        last = int(time.time())
        if first == 0:
            first = last
        cookie = nagiosplugin.Cookie(cookiefile)
        cookie.set(pickle.dumps(dict(data.items() + {last: datum}.items())))
        cookie.close()
        # shared cache
        try:
            os.chmod(cookiefile, stat.S_IRUSR|stat.S_IWUSR|stat.S_IRGRP|stat.S_IWGRP|stat.S_IROTH|stat.S_IWOTH)
        except:
            pass


    else:
        datum = data[last]

    dom = minidom.parseString(datum)

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
