#!/usr/bin/python26
#
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_dns_service.py#1 $
#

"""Used to monitor our two dns services (sbrs, sb) clusters for capacity issues."""


import urllib2
import sys
import os

from pysnmp.entity.rfc3413.oneliner import cmdgen

def check_qps(host, passwd):
    oid = '1.3.6.1.4.1.2021.8.1.101.1'
    oid = '1.3.6.1.4.1.8072.1.3.2.3.1.2.6.100.110.115.113.112.115'
    oid = tuple([int(x) for x in oid.split('.')])
    results = cmdgen.CommandGenerator().getCmd(
        cmdgen.CommunityData('test-agent', passwd, 0),
        cmdgen.UdpTransportTarget((host, 161)), oid)

    return float(str(results[3][0][1]))

def get_hosts(**server_filters):
    base_url = "http://asdb.ironport.com/servers/list/?"
    x = []
    for filter in server_filters.iterkeys():
        x.append('%s__name__exact=%s' % (filter, server_filters[filter]))

    url = base_url + '&'.join(x)

    web_req = urllib2.urlopen(url)
    return web_req.read().split()

if __name__ == '__main__':
    import optparse

    opt_parser = optparse.OptionParser()

    opt_parser.add_option("-p", "--passwd",
            help="SNMP password.")
    opt_parser.add_option("--product",
            help="Product to monitor.")
    opt_parser.add_option("-w", "--warning",
            help="Sets the thresholds which will trigger a warning " + \
                 "alert.  Must be two % values, separated by a comma. " + \
                 "The first value is a % of total cluster capacity. " + \
                 "The second is a % of any individual server's " + \
                 "capacity.  (ie: -w 30%,50%)")
    opt_parser.add_option("-c", "--critical",
            help="Sets the thresholds which will trigger a critical " + \
                 "alert.  Must be two % values, separated by a comma. " + \
                 "The first value is a % of total cluster capacity. " + \
                 "The second is a % of any individual server's " + \
                 "capacity.  (ie: -c 30%,50%)")
    opt_parser.add_option("-H", "--host",
            help="Specifies a host to monitor specifically.")
    opt_parser.add_option("--server_capacity", type="int",
            help="Specifies the maximum queries per second that a single " + \
                 "server can handle in the cluster.")

    (opts, args) = opt_parser.parse_args()

    if not (opts.product and opts.warning and opts.critical and opts.product and opts.server_capacity):
        print "Must specify -p, -w, -c, --product and --server_capacity options."
        opt_parser.print_help()
        sys.exit(2)

    warning = opts.warning.replace('%','')

    warning = [float(x)/100.0 for x in warning.split(',')]

    critical = opts.critical.replace('%','')

    critical = [float(x)/100.0 for x in critical.split(',')]

    # Figure out what hosts to monitor
    hosts = get_hosts(product=opts.product, purpose='ns', environment='prod')
    host_count = len(hosts)

    total_cluster_capacity = opts.server_capacity * host_count

    critical_server_capacity = opts.server_capacity * critical[1]
    warning_server_capacity = opts.server_capacity * warning[1]

    total_qps = 0
    warning_hosts = []
    critical_hosts = []
    
    for host in hosts:
        qps = check_qps(host, opts.passwd)

        total_qps += qps

        if qps > critical_server_capacity:
            # crit
            critical_hosts.append(host)

        if qps > warning_server_capacity and qps < critical_server_capacity:
            # warning
            warning_hosts.append(host)

    critical_host_count = len(critical_hosts)
    warning_host_count = len(warning_hosts)

    # 0 means 'ok'
    exit = 0

    if total_qps > total_cluster_capacity * warning[0] or warning_host_count > 0:
        # Warn Cluster
        exit = 1

    if warning_host_count > 0:
        exit = 1

    if total_qps > total_cluster_capacity * critical[0] or critical_host_count > 0:
        exit = 2

    if exit == 0: msg = "OK - "
    if exit == 1: msg = "WARNING - "
    if exit == 2: msg = "CRITICAL - "

    msg += "Cluster capacity @ %d%%. " % ((total_qps / total_cluster_capacity)*100)
    msg += " %d hosts at critical. %d hosts at warning. (Execute by hand to get a list of hosts.)" % (critical_host_count, warning_host_count)

    if critical_host_count > 0:
        msg += "\n    Critical Hosts: %s" % (', '.join(critical_hosts))
    if warning_host_count > 0:
        msg += "\n    Warning Hosts: %s" % (', '.join(warning_hosts))

    print msg
    sys.exit(exit)
