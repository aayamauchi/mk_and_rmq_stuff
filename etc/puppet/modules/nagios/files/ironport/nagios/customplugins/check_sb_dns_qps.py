#!/usr/bin/python26
# 
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_sb_dns_qps.py#1 $
#

"""
Used to check the qps of our dns services via snmp and alert whenever that value
crosses a threshold.
"""

__version__ = '$Revision: #1 $'


import urllib2
import sys
import os

from pysnmp.entity.rfc3413.oneliner import cmdgen

def check_qps(host, passwd):
    opts.oid = tuple([int(x) for x in opts.oid.split('.')])
    results = cmdgen.CommandGenerator().getCmd(
        cmdgen.CommunityData('test-agent', passwd, 0),
        cmdgen.UdpTransportTarget((host, 161)), opts.oid)
    
    return float(str(results[3][0][1]))

if __name__ == '__main__':
    import optparse

    cmd_parser = optparse.OptionParser(usage="usage: %prog [options] host")
    cmd_parser.add_option('-p', '--passwd',
            help='SNMP community string.')
    cmd_parser.add_option('-w', '--warning', type="int",
            help="Sets warning threshold for qps.")
    cmd_parser.add_option('-c', '--critical', type="int",
            help="Sets critical threshold for qps.")
    cmd_parser.add_option('-o', '--oid', type="string",
            help="Optionally sets the oid to query.", default='1.3.6.1.4.1.2021.8.1.101.1')

    (opts, args) = cmd_parser.parse_args()

    try:
        host = args[0]
    except IndexError:
        print "CRITICAL - No host specified."
        cmd_parser.print_help()
        sys.exit(2)

    if opts.passwd == None:
        print "CRITICAL - Must provide community string with -p."
        cmd_parser.print_help()
        sys.exit(2)

    qps = check_qps(host, opts.passwd)

    if opts.warning == None and opts.critical == None:
        print "Host %s is serving %d queries/second." % (host, qps)
        sys.exit(0)

    if qps > opts.critical:
        print "CRITICAL - Current qps (%d) is greater than threshold (%d)." \
              " | qps=%d" % (qps, opts.critical, qps)
        sys.exit(2)

    if qps > opts.warning:
        print "WARNING - Current qps (%d) is greater than threshold (%d)." \
              " | qps=%d" % (qps, opts.warning, qps)
        sys.exit(1)

    print "OK - Current qps (%d) is below all thresholds. |" \
          " qps=%d" % (qps, qps)
