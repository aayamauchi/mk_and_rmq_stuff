#!/usr/bin/python26
# 
# Used to either monitor (nagios) or gather (cacti) statistics from the
# phonehome server statistics port.  This is new in updater 1.6 and should
# start to show up in other phonehome server based products as they get 
# updatd.
#
# $Id: //sysops/main/puppet/test/modules/cacti/files/cacti/scripts/check_phonehome_stats.py#1 $
#

import optparse
import traceback
import sys
import simplejson
import string
import socket
import urllib2
import urllib
import types
import operator

def setup_options():
    """Used to setup the options for the option parser.  Returns the """ \
            """populated option_parser."""
    usage = "usage: %prog [options] host"
    # Setup options
    option_parser = optparse.OptionParser(usage=usage)
    option_parser.add_option('-r', '--resource', dest='resource',
            help="The resource record to query.  Comma delimeted for RPN input.")
    option_parser.add_option('-w', '--warning', type='float', dest='warning',
            help="Set the warning threshold.")
    option_parser.add_option('-c', '--critical', type='float', dest='critical',
            help="Set the critical threshold.")
    option_parser.add_option('-p', '--port', type='int', dest='port',
            default=8080,
            help="The port to query.  Default: %default")
    option_parser.add_option('--gt', action='store_true', dest='gt',
            help="Throw alerts when the returned value is greater than " \
                    "the limits provided via -w and -c.")
    option_parser.add_option('--lt', action='store_true', dest='lt',
            help="Throw alerts when the returned value is less than " \
                    "the limits provided via -w and -c.")
    option_parser.add_option('-t', '--timeout', type='int', dest='timeout', default=5,
            help="Set the timeout in seconds to retrieve stats from server, default: %default seconds.")
    return option_parser

def parse_options(option_parser):
    # Parse the arguments
    try:
        (options, args) = option_parser.parse_args()
    except optparse.OptParseError:
        print "CRITICAL - Invalid commandline arguments."
        option_parser.print_help()
        traceback.print_exc()
        sys.exit(2)
    # The host is a required argument
    if not len(args):
        print "CRITICAL - Missing host argument."
        option_parser.print_help()
        sys.exit(2)
    # If critical or warning specified, then you must specify gt or lt 
    # as well
    if options.critical or options.warning:
        if (not options.gt and not options.lt) or (options.gt and options.lt):
            print "CRITICAL - You must provide either --gt or --lt when " \
                    "specifying warning or critical thresholds."
            option_parser.print_help()
            sys.exit(2)
        if not options.resource:
            print "CRITICAL - You must specify a --resource when specifying " \
                    "warning or critical thresholds."
            option_parser.print_help()
            sys.exit(2)
    return (options, args)

def rpn(rpnstack, data):
    rpnstack = rpnstack.split(',')
    if len(rpnstack) > 1:
        ops = [operator.add,operator.sub,operator.mul,operator.div]
        rpn = []
        for tk in rpnstack:
            oi = string.find('+-*/',tk)
            if len(rpn)==2 and oi>=0:
                rpn = [ops[oi](rpn[0],rpn[1])]
            else:
                try:
                    x = float(tk)
                except:
                    try:
                        rpn.append(float(data[tk]))
                    except:
                        print "Unable to find %s" % (tk)
                        print "Valid options are:"
                        for key in sorted(data.keys()):
                            print key
                        sys.exit(3)
                else:
                    print rpn, float(tk)
                    rpn.append(float(tk))
        rpnstack = rpn.pop()
    else:
        try:
            rpnstack = data[rpnstack[0]]
        except:
            print "Unable to find %s in data." % (rpnstack[0])
            print "Valid options are:"
            for key in sorted(data.keys()):
                print key
            sys.exit(3)
    return float(rpnstack)

if __name__ == '__main__':
    option_parser = setup_options()
    (options, args) = parse_options(option_parser)
    host = args[0]

    socket.setdefaulttimeout(options.timeout)
    url = "http://%s:%d" % (host, options.port)
    try:
        http_connection = urllib2.urlopen(url)
    except:
        sys.exit(3)
    else:
        data_dict = simplejson.load(http_connection)[host]

    data = {}

    if data_dict.has_key('build'):
        # New style stats.
        timekey = sorted(data_dict['recent'].keys())[-1]
        data['current_connections'] = data_dict['recent'][timekey]['open_connections']['avg']
        data['avg_connect_time'] = data_dict['recent'][timekey]['connection_times']['100']['avg']
        data['max_connect_time'] = data_dict['recent'][timekey]['connection_times']['100']['max']
        data['max_connections'] = data_dict['recent'][timekey]['open_connections']['max']
        # No longer counters!
        data['auth_success'] = data_dict['recent'][timekey]['auth_stats'].get('success', 0)
        data['auth_failure'] = data_dict['recent'][timekey]['auth_stats'].get('failure', 0)
        data['auth_null'] = data_dict['recent'][timekey]['auth_stats'].get('null', 0)
        # Still a counter
        data['total_connections'] = data_dict['total_connections']
        data['exceptions'] = 0
        for key in data_dict['recent'][timekey]['exceptions'].keys():
            data['exceptions'] += data_dict['recent'][timekey]['exceptions'][key]
        for tile in data_dict['config']['tiles']:
            if tile == 100: continue
            data['avg_connect_time_%s' % (tile)] = \
                    data_dict['recent'][timekey]['connection_times'][str(tile)]['avg']
            data['max_connect_time_%s' % (tile)] = \
                    data_dict['recent'][timekey]['connection_times'][str(tile)]['max']
    else:
        # old style stats.
        data['current_connections'] = data_dict['current_connections']
        data['avg_connect_time'] = data_dict['recent_stats']['avg_connection_time']
        data['max_connect_time'] = data_dict['recent_stats']['max_connection_time']
        data['max_connections'] = data_dict['recent_stats']['max_concurrent_connections']
        # Counters!
        data['auth_success'] = data_dict['auth_stats'].get('success', 0)
        data['auth_failure'] = data_dict['auth_stats'].get('failure', 0)
        data['auth_null'] = data_dict['auth_stats'].get('null', 0)
        data['total_connections'] = data_dict['total_connections']
        data['exceptions'] = data_dict['recent_stats'].get('exceptions', 0)


    if options.warning or options.critical:
        # Nagios monitor
        datum = rpn(options.resource, data)
        # Pick the right function & operator name depending on whether or not
        # the gt or lt options were used.
        if options.gt:
            operator_function = operator.gt
            operator_name = "greater"
        if options.lt:
            operator_function = operator.lt
            operator_name = "lesser"
        # Test to see if the data violates the critical threshold
        if options.critical != None \
                and operator_function(datum, options.critical):
            print "CRITICAL - Resource '%s' returned value (%s) %s " \
                    "than threshold (%s)." % (options.resource, datum,
                            operator_name, options.critical)
            sys.exit(2)
        # Test to see if the data violates the warning threshold
        if options.warning != None \
                and operator_function(datum, options.warning):
            print "WARNING - Resource '%s' returned value (%s) %s " \
                    "than threshold (%s)." % (options.resource, datum,
                            operator_name, options.warning)
            sys.exit(1)
        # Everything looks good.
        print "OK - Resource '%s' returned %s." % (options.resource, datum)
        sys.exit(0)
    else:
        # Cacti monitor
        for key in sorted(data.keys()):
            if data[key] != int(data[key]):
                print "%s:%0.3f" % (key, data[key]),
            else:
                print "%s:%s" % (key, data[key]),
        print
