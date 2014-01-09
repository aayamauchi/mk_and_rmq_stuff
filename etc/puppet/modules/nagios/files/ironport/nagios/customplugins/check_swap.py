#!/usr/bin/python26
#
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_swap.py#3 $
#

"""Used to get current swap percentage."""

import urllib2
import sys
import os

import warnings
warnings.filterwarnings('ignore', '.*', DeprecationWarning)

from pysnmp.entity.rfc3413.oneliner import cmdgen

def check_swap(host, passwd):
    oidtot = '1.3.6.1.4.1.2021.4.3.0'
    oidava = '1.3.6.1.4.1.2021.4.4.0'
    oidtot = tuple([int(x) for x in oidtot.split('.')])
    oidava = tuple([int(x) for x in oidava.split('.')])
    resulttot = cmdgen.CommandGenerator().getCmd(
        cmdgen.CommunityData('test-agent', passwd, 0),
        cmdgen.UdpTransportTarget((host, 161)), oidtot)[3][0][1]
    resultava = cmdgen.CommandGenerator().getCmd(
        cmdgen.CommunityData('test-agent', passwd, 0),
        cmdgen.UdpTransportTarget((host, 161)), oidava)[3][0][1]
    return int((float(resultava)/float(resulttot))*100)

if __name__ == '__main__':
    import optparse

    opt_parser = optparse.OptionParser()

    opt_parser.add_option("-p", "--passwd",
            help="SNMP password.")
    opt_parser.add_option("-w", "--warning", type="int",
            help="Percent available swap to warn at.")
    opt_parser.add_option("-c", "--critical", type="int",
            help="Percent available swap to critical at.")
    opt_parser.add_option("-H", "--host",
            help="Specifies a host.")

    (opts, args) = opt_parser.parse_args()

    if not (opts.warning and opts.critical and opts.host):
        print "Must specify -w, -c, and -H options."
        opt_parser.print_help()
        sys.exit(3)
    if (opts.warning < opts.critical):
        print "Critical must be less than Warning threshold"
	opt_parser.print_help()
	sys.exit(3)

    swap = check_swap(opts.host, opts.passwd)

    # 0 means 'ok'
    exit = 0

    if (swap < opts.critical):
        exit = 2
    elif (swap < opts.warning):
        exit = 1

    if exit == 0: msg = "OK - "
    if exit == 1: msg = "WARNING - "
    if exit == 2: msg = "CRITICAL - "

    msg += "Swap at %s %% available" % (swap)

    print msg
    sys.exit(exit)
