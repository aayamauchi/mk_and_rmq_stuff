#!/usr/bin/python26
#
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_snmp_cpu.py#1 $
#

"""Used to get current cpu percentage.
Some net-snmp installs will report 50% cpu, all the time, no
matter what.  Grr."""

import warnings
warnings.filterwarnings('ignore', '.*', DeprecationWarning)
import urllib2
import sys
import os
import simplejson
import time
import stat

from pysnmp.entity.rfc3413.oneliner import cmdgen

def check_cpu(host, passwd):
    oid = {}
    result = {}
    oididle = '1.3.6.1.4.1.2021.11.53.0'
    oid['user'] = '1.3.6.1.4.1.2021.11.50.0'
    oid['nice'] = '1.3.6.1.4.1.2021.11.51.0'
    oid['system'] = '1.3.6.1.4.1.2021.11.52.0'
    #oid['wait'] = '1.3.6.1.4.1.2021.11.54.0'
    #oid['kernel'] = '1.3.6.1.4.1.2021.11.55.0'
    #oid['interrupt'] = '1.3.6.1.4.1.2021.11.56.0'
    oididle = tuple([int(x) for x in oididle.split('.')])
    resultidle = int(cmdgen.CommandGenerator().getCmd(
        cmdgen.CommunityData('test-agent', passwd, 1),
        cmdgen.UdpTransportTarget((host, 161)), oididle)[3][0][1])
    time.sleep(0.1)
    if resultidle == 0:
        resultidle = int(cmdgen.CommandGenerator().getCmd(
            cmdgen.CommunityData('test-agent', passwd, 1),
            cmdgen.UdpTransportTarget((host, 161)), oididle)[3][0][1])
    for key in oid.keys():
        oid[key] = tuple([int(x) for x in oid[key].split('.')])
        try:
            result[key] = int(cmdgen.CommandGenerator().getCmd(
                cmdgen.CommunityData('test-agent', passwd, 1),
                cmdgen.UdpTransportTarget((host, 161)), oid[key])[3][0][1])
            time.sleep(0.1)
        except:
            try:
                result[key] = int(cmdgen.CommandGenerator().getCmd(
                    cmdgen.CommunityData('test-agent', passwd, 1),
                    cmdgen.UdpTransportTarget((host, 161)), oid[key])[3][0][1])
            except:
                del result[key]
        if result[key] == 0:
            try:
                result[key] = int(cmdgen.CommandGenerator().getCmd(
                    cmdgen.CommunityData('test-agent', passwd, 1),
                    cmdgen.UdpTransportTarget((host, 161)), oid[key])[3][0][1])
            except:
                del result[key]

    return { 'time' : int(time.time()), 'idle' : resultidle, 'used' : result }

# format:
# { 'timestamp' : #, 'idle' : #, used : { 'user' : #, etc }
def read_file(host):
    try:
        cache = open('/tmp/tmp_Nagios_cpu.%s' % (host), 'r')
    except:
        return None
    else:
        cachedata = cache.read()
        cachedata = simplejson.loads(cachedata)
        return cachedata

def write_file(host, cachedata):
    file = '/tmp/tmp_Nagios_cpu.%s' % (host)
    try:
        cache = open(file, 'w')
    except:
        print "Unable to write cache file"
        sys.exit(3)
    else:
        cache.write(simplejson.dumps(cachedata))
    cache.close()
    try:
    	os.chown(file, os.geteuid, -1)
    	os.chmod(file, stat.S_IRUSR| stat.S_IRGRP | stat.S_IROTH | stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH )
    except:
    	x = 1

        
def calc_cpu(nowdata, cachedata):
    idleticks = nowdata['idle'] - cachedata['idle']
    usedticks = 0
    for key in nowdata['used'].keys():
        usedticks += nowdata['used'][key]
    for key in cachedata['used'].keys():
        usedticks -= cachedata['used'][key]
    if usedticks < 0:
        print "snmpd has been restarted"
        write_file(host, nowdata)
        sys.exit(3)
    totalticks = usedticks + idleticks
    cpu = 100 - int((float(idleticks)/float(totalticks))*100)
    print "CPU at %s%% utilization" % (cpu)
    if cpu < opts.warning: sys.exit(0)
    if cpu >= opts.critical: sys.exit(2)
    sys.exit(1)

if __name__ == '__main__':
    import optparse

    opt_parser = optparse.OptionParser()

    opt_parser.add_option("-p", "--passwd",
            help="SNMP password.")
    opt_parser.add_option("-w", "--warning", type="int",
            help="Percent available cpu to warn at.")
    opt_parser.add_option("-c", "--critical", type="int",
            help="Percent available cpu to critical at.")
    opt_parser.add_option("-H", "--host",
            help="Specifies a host.")

    (opts, args) = opt_parser.parse_args()

    if not (opts.warning and opts.critical and opts.host):
        print "Must specify -w, -c, and -H options."
        opt_parser.print_help()
        sys.exit(3)
    if (opts.warning > opts.critical):
        print "Critical must be greater than or equal to Warning threshold"
	opt_parser.print_help()
	sys.exit(3)

    try:
        nowdata = {}
        nowdata = check_cpu(opts.host, opts.passwd)
    except:
        print "CRITICAL - snmp error"
	sys.exit(3)

    cachedata = read_file(opts.host)

    if not cachedata:
        write_file(opts.host, [nowdata])
        print "First run, nothing to compare against"
        sys.exit(3)

    for line in cachedata:
        if line['time'] < (nowdata['time'] - 60):
            write_file(opts.host, [nowdata, line])
            calc_cpu(nowdata, line)
    print "Not enough historical data to calculate"
    sys.exit(3)

print "Fell through!"
sys.exit(3)
