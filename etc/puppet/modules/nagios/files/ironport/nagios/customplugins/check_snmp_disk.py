#!/usr/bin/python26
#
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_snmp_disk.py#2 $
#

"""Used to query an disk stats over snmp.  Understands
    standard disk oids, as well as netapp oids."""

import warnings
warnings.filterwarnings('ignore', '.*', DeprecationWarning)
import time
import sys
import os
import string
import operator

from pysnmp.entity.rfc3413.oneliner import cmdgen

def check_disk(host, passwd, disk, netapp=False):
    msg = ''
    exit = 0
    done = False
    data = {}
    oidbase = '1.3.6.1.4.1.'
    if netapp:
        oidindex = oidbase + '789.1.5.4.1.10'
        oidfull = oidbase + '789.1.5.4.1.6'
        oidinodes = oidbase + '789.1.5.4.1.9'
    else:
        oidindex = oidbase + '2021.9.1.2'
        oidfull = oidbase + '2021.9.1.9'
        oidinodes = oidbase + '2021.9.1.10'

    index = 1
    indexes = []
    newindexes = []
    indexok = False
    indexfile = '/tmp/check_snmp_disk.py_%s-%s' % (host, str(disk).strip("[]").replace('/','-'))
    t_file = 0
    if os.path.exists(indexfile) and disk is not None:
        t_now = int(time.time())
        try:
            t_file = os.path.getmtime(indexfile)
        except:
            if opts.verbose:
                print "Unable to stat index file, continuing in raw mode."
        else:
            if ((t_now - t_file) < opts.expire):
                try:
                    indexes = open(indexfile).readlines()
                except:
                    if opts.verbose:
                        print "Unable to read index file, continuing in raw mode."
                else:
                    try:
                        index = int(indexes.pop())
                    except:
                        if opts.verbose:
                            print "Error popping from index, %s" % str((indexes))
                    else:
                        indexok = True
            else:
                if opts.verbose:
                    print "Index file has expired, continuing in raw mode. Will try to update index file later on."

    while not done:
        oid = tuple([int(x) for x in oidindex.split('.') + [index]])
        if opts.verbose:
            print "About to query oid %s" % (str(oid))
        result = cmdgen.CommandGenerator().getCmd(
            cmdgen.CommunityData('test-agent', passwd, 0),
            cmdgen.UdpTransportTarget((host, 161)), oid)
        if opts.verbose:
            print "Result: %s" % (str(result))
            print "Result301: '%s'" % (str(result[3][0][1]))
        if result[0] != None:
            msg += "%s\n" % (result[0])
            done = True
            exit = 3
        elif result[1] != 0:
            if msg == '':
		if result[1] == 2:
                    msg = "Unable to find disk '%s' on host\n" % (disk)
                else:
                    msg = "Unhandled error '%s' on '%s'\n" % (result[1], str(result[3][0]))
		exit = 3
            elif disk is not None and disk != '':
                msg += "Unable to find %s on host" % (disk)
                if exit == 0:
                    exit = 3
            if indexok:
                indexok = False
                indexes = []
            else:
                done = True
        elif ((disk is not None and result[3][0][1] in disk) or disk is None) and \
                (result[3][0][1] != ''):
            oid = tuple([int(x) for x in oidfull.split('.') + [index]])
            used = 0
            inodes = 0
            try:
                used = int(cmdgen.CommandGenerator().getCmd(
                    cmdgen.CommunityData('test-agent', passwd, 0),
                    cmdgen.UdpTransportTarget((host, 161)), oid)[3][0][1])
            except:
                msg += "Unable to collect disk utilization data for %s\n" % (disk)
                exit = 3
            oid = tuple([int(x) for x in oidinodes.split('.') + [index]])
            try:
                inodes = int(cmdgen.CommandGenerator().getCmd(
                    cmdgen.CommunityData('test-agent', passwd, 0),
                    cmdgen.UdpTransportTarget((host, 161)), oid)[3][0][1])
            except:
                msg += "Unable to collect disk utilization data for %s\n" % (disk)
                exit = 3
            msg += "[%s] Disk %s%%, Inodes %s%%\n" % (result[3][0][1], used, inodes)
            if disk is not None:
                disk.remove(result[3][0][1])
                newindexes.append(index)
            if (used > opts.critical) or (inodes > opts.critical):
                exit = 2
            if ((used > opts.warning) or (inodes > opts.critical)) and exit == 0:
                exit = 1
            if (disk is not None and disk == []):
                done = True
        elif (indexok and result[3][0][1] not in disk):
            indexok = False
            index = 0
        elif (result[3][0][1] == ''):
            done = True
        if indexok and len(disk):
            index = int(indexes.pop())
        else:
            index += 1

    if (opts.disk is not None and not indexok):
        if (len(newindexes) > 0):
            try:
                index_fh = open(indexfile, 'w')
            except:
                if opts.verbose:
                    print "Unable to open indexfile for writing."
            else:
                for index in newindexes:
                    index_fh.write('%s\n' % (index))
                index_fh.close()
                os.chmod(indexfile, 0666)
        else:
            exit = 3
            msg = "%s does not exist!" % (str(opts.disk).replace("'", ""))
        
    return exit, msg

if __name__ == '__main__':
    import optparse

    opt_parser = optparse.OptionParser()

    opt_parser.add_option("-p", "--passwd",
            help="SNMP password.")
    opt_parser.add_option("-d", "--disk",
            help="""Disk or Volume to query.  Comma separated values to test multiples.
Test all against threshold, if not passed.""")
    opt_parser.add_option("-w", "--warning", type="int",
            help="Value to warn at.")
    opt_parser.add_option("-c", "--critical", type="int",
            help="Value to critical at.")
    opt_parser.add_option("-e", "--expire", type="int", dest="expire",
            help="Max age of snmp index cache for given host/disk.", default=7200)
    opt_parser.add_option("-H", "--host",
            help="Specifies a host.")
    opt_parser.add_option("--netapp", action="store_true", default=False,
            help="NetApp, not host.  Adjust oid appropriately.")
    opt_parser.add_option("-v", "--verbose", action="store_true", default=False,
            help="Output verbose information.")

    (opts, args) = opt_parser.parse_args()
    if opts.disk is not None:
        opts.disk = str(opts.disk).split(',')

    if not (opts.warning and opts.critical and opts.host):
        print "Must specify -w, -c, and -H options."
        opt_parser.print_help()
        sys.exit(3)
    if (opts.warning > opts.critical):
        print "Critical must be more than Warning threshold"
	opt_parser.print_help()
	sys.exit(3)

    exit, msg = check_disk(opts.host, opts.passwd, opts.disk, opts.netapp)

    if exit == 0: msg = "OK - " + msg
    elif exit == 1: msg = "WARNING - " + msg
    elif exit == 2: msg = "CRITICAL - " + msg
    elif exit == 3: msg = "UNKNOWN - " + msg

    print msg,
    sys.exit(exit)
