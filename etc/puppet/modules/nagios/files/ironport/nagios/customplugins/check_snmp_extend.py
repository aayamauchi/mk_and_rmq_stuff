#!/usr/bin/python26
#
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_snmp_extend.py#1 $
#

"""Used to query an extend declaration, and where
   needed, store state for counters.  Also understands
   cacti-style name:value format for parsing."""

import warnings
warnings.filterwarnings('ignore', '.*', DeprecationWarning)
import time
import sys
import os
import string
import operator

from pysnmp.entity.rfc3413.oneliner import cmdgen

def check_extend(host, passwd, extend):
    oid = '1.3.6.1.4.1.8072.1.3.2.3.1.2.'
    oid += "%s." % (len(extend))
    for char in extend:
        oid += str(ord(char))
        oid += "."
    oid = oid[:-1]
    oid = tuple([int(x) for x in oid.split('.')])
    result = cmdgen.CommandGenerator().getCmd(
        cmdgen.CommunityData('test-agent', passwd, 0),
        cmdgen.UdpTransportTarget((host, 161)), oid)[3][0][1]
    return str(result).lower()

if __name__ == '__main__':
    import optparse

    opt_parser = optparse.OptionParser()

    opt_parser.add_option("-p", "--passwd",
            help="SNMP password.")
    opt_parser.add_option("-e", "--extend",
            help="Extend declaration to query.")
    opt_parser.add_option("-w", "--warning", type="int",
            help="Value to warn at.")
    opt_parser.add_option("-c", "--critical", type="int",
            help="Value to critical at.")
    opt_parser.add_option("-H", "--host",
            help="Specifies a host.")
    opt_parser.add_option("-n", "--name",
            help="Grep out a value from name:value paired output.")
    opt_parser.add_option("--rpn", type="string",
            help="Reverse Polish Notation functions.")
    opt_parser.add_option("--cache", action="store_true", default=False,
            help="Cache data and check delta against threshold.\
            Values are tested per-minute.")

    (opts, args) = opt_parser.parse_args()

    if not (opts.warning and opts.critical and opts.host):
        print "Must specify -w, -c, and -H options."
        opt_parser.print_help()
        sys.exit(3)
    if (opts.warning > opts.critical):
        print "Critical must be more than Warning threshold"
	opt_parser.print_help()
	sys.exit(3)
    if (opts.name and opts.rpn):
        print "Pass only one of --name and --rpn"
        opt_parser.print_help()
        sys.exit(3)
    if (opts.cache and opts.rpn):
        print "Pass only one of --cache and --rpn"
        opt_parser.print_help()
        sys.exit(3)

    try:
        result = check_extend(opts.host, opts.passwd, opts.extend)
    except:
        print "CRITICAL - snmp error"
	sys.exit(2)

    if opts.cache:
        if opts.name:
            statefile = "/tmp/%s_%s_%s-%s" % (sys.argv[0].split('/')[-1], opts.host, opts.extend, opts.name)
        else:
            statefile = "/tmp/%s_%s_%s" % (sys.argv[0], opts.host, opts.extend)
        if os.path.exists(statefile):
            then = os.stat(statefile)[-2]
            state = open(statefile, 'r').read()
            now = time.time()
            file = open(statefile, 'w')
            print >>file, result
            file.close()
        else:
            if opts.name:
                if str(opts.name).lower() not in result:
                    print "CRITICAL - Did not find %s in current result" % (opts.name)
                    sys.exit(2)
            file = open(statefile, 'w')
            print >>file, result
            file.close()
            print "UNKNOWN - No state found, writing initial state."
            sys.exit(3)
        if opts.name:
            opts.name = str(opts.name).lower()
            current_val = None
            previous_val = None
            for name in result.split():
                if name.startswith("%s:" % (opts.name)):
                    current_val = name.split(':')[1]
                    continue
            if not current_val:
                print "CRITICAL - Did not find %s in current result" % (opts.name)
                sys.exit(2)
            for name in state.split():
                if name.startswith("%s:" % (opts.name)):
                    previous_val = name.split(':')[1]
                    continue
            if not previous_val:
                print "CRITICAL - Did not find %s in previous result" % (opts.name)
                sys.exit(2)
        else:
            current_val = result
            previous_val = state
        delta = float(current_val) - float(previous_val)
        timed = now - then
        value = (delta / timed) * 60
    else:
        if opts.name:
            opts.name = str(opts.name).lower()
            value = None
            for name in result.split():
                if name.startswith("%s:" % (opts.name)):
                    value = float(name.split(':')[1])
                    continue
            if value == None:
                print "CRITICAL - Did not find %s in result" % (opts.name)
                sys.exit(2)
        elif opts.rpn:
            opts.rpn = str(opts.rpn).lower()
            values = {}
            for name in result.split():
                values[name.split(':')[0]] = float(name.split(':')[1])
            # RPN code snagged from the internet.
            ops = [operator.add,operator.sub,operator.mul,operator.div]
            rpn = []
            opts.rpn = str(opts.rpn).lower()
            for tk in str(opts.rpn).split(','):
                oi = string.find('+-*/',tk)
                if len(rpn)>=2 and oi>=0:
                    rpn = rpn[0:-2] + [ops[oi](rpn[-2],rpn[-1])]
                else:
                    try:
                        x = float(tk)
                    except:
                        try:
                            rpn.append(float(values[tk]))
                        except:
                            print "Unable to find %s in %s" % (tk, values)
                            sys.exit(3)
                    else:
                        rpn.append(float(tk))

            value = rpn.pop()
        else:
            value = result

    # 0 means 'ok'
    exit = 0

    value = int(value)
    if (value > opts.critical):
        exit = 2
    elif (value > opts.warning):
        exit = 1

    if exit == 0: msg = "OK - "
    if exit == 1: msg = "WARNING - "
    if exit == 2: msg = "CRITICAL - "

    if opts.name:
        msg += "%s/%s at %s" % (opts.extend, opts.name, value)
    elif opts.rpn:
        msg += "%s/'%s' at %s" % (opts.extend, opts.rpn, value)
    else:
        msg += "%s at %s" % (opts.extend, value)

    if opts.cache:
        msg += " per minute"

    print msg
    sys.exit(exit)
