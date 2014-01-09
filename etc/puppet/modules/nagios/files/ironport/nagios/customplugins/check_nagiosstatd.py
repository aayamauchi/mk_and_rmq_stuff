#!/usr/bin/python26
#==============================================================================
# check_nagiosstatd.py
#
# Checks for proper nagiosstatd operation by inspecting the results of a query.
#
# 2011-10-15 jramache
#==============================================================================
import optparse
import sys
import simplejson
import os

def setup_options():
    """Used to setup the options for the option parser.  Returns the """ \
            """populated option_parser."""
    usage = "usage: %prog [-c clientpath] -q query"
    option_parser = optparse.OptionParser(usage=usage)
    option_parser.add_option('-c', '--client', type='string', dest='nagiosstatc',
            default="/usr/local/ironport/nagios/bin/nagiosstatc",
            help="Full path to nagiosstatc client. Default: %default")
    option_parser.add_option('-q', '--query', type='string', dest='query',
            default='',
            help="Query to run.")
    option_parser.add_option('-v', '--verbose', action='store_true', dest='verbose',
            default=False,
            help="Verbose output.")
    return option_parser

def parse_options(option_parser):
    try:
        (options, args) = option_parser.parse_args()
    except optparse.OptParseError:
        print "CRITICAL - Invalid command line arguments"
        option_parser.print_help()
        traceback.print_exc()
        sys.exit(2)
    if options.query == '':
        print "CRITICAL - Query not provided in command line arguments"
        option_parser.print_help()
        sys.exit(2)
    return (options, args)

if __name__ == '__main__':
    option_parser = setup_options()
    (options, args) = parse_options(option_parser)

    if options.verbose:
        print ">>>>> Executing '%s -q \"%s\"'" % (options.nagiosstatc, options.query)
    fh = os.popen('%s -q "%s" 2>/dev/null' % (options.nagiosstatc, options.query))
    try:
        if options.verbose:
            print ">>>>> Parsing results"
        json = simplejson.loads(fh.read())
    except ValueError:
        print "CRITICAL - Unable to load and parse json"
        sys.exit(2)
    fh.close()

    if options.verbose:
        print ">>>>> Inspecting json data:"
        print simplejson.dumps(json, indent=4)

    if 'query_ok' not in json:
        print "CRITICAL - Query status not included in json result"
        sys.exit(2)

    if not json['query_ok']:
        try:
            message = json['rows'][0]['value']
        except:
            message = '<error message not found>'
        print "CRITICAL - Query failure: %s" % (message)
        sys.exit(2)

    print "OK - Query returned valid result"
    sys.exit(0)
