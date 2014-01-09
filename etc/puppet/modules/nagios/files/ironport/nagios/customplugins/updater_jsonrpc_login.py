#!/usr/bin/python26
#==============================================================================
# updater_jsonrpc_login.py
#
# Tests the Updater RPC server authentication mechanism by attempting to login
# as user nagios. The username and password are hard coded into this script.
#
# Requested via RT:128003 for Updater 1.7 release to stage.
#
# ENG spec:
# http://eng.ironport.com/docs/cpt/proj/updater/1.7/design_specs/rpc_interface.rst
#
# Jeff Ramacher (jramache@cisco.com) 2/15/2011
#==============================================================================
import optparse
import sys
import urllib2
from urllib2 import URLError
import simplejson

def setup_options():
    """Used to setup the options for the option parser.  Returns the """ \
            """populated option_parser."""
    usage = "usage: %prog [options] host"
    # Setup options
    option_parser = optparse.OptionParser(usage=usage)
    option_parser.add_option('-p', '--port', type='int', dest='port',
            default=8081,
            help="The port to query. Default: %default")
    option_parser.add_option('--nossl', action='store_true', dest='nossl',
            default=False,
            help="Prevent SSL connection. Default: %default")
    return option_parser

def parse_options(option_parser):
    # Parse the arguments
    try:
        (options, args) = option_parser.parse_args()
    except optparse.OptParseError:
        print "CRITICAL - Invalid commandline arguments"
        option_parser.print_help()
        traceback.print_exc()
        sys.exit(2)
    # The host is a required argument
    if not len(args):
        print "CRITICAL - Missing host argument"
        option_parser.print_help()
        sys.exit(2)
    return (options, args)

if __name__ == '__main__':
    option_parser = setup_options()
    (options, args) = parse_options(option_parser)
    host = args[0]

    username = 'nagios'
    password = 'n{ue>3ZRp!`"_|:Kq\ElaWPs)xgn+GQ|'

    # Default to UNKNOWN result
    ret_code = 3

    if (options.nossl):
        reqUrl = "http://%s:%d" % (host, options.port)
    else:
        reqUrl = "https://%s:%d" % (host, options.port)

    reqData = '{"params": {"username": ' + simplejson.dumps(username) + ', "password": ' + simplejson.dumps(password) + '}, "jsonrpc": "2.0", "method": "users.login", "id": 0}'
    reqHeaders = {
        "Accept-encoding": "application/json-rpc",
        "Content-type": "application/json-rpc",
        "Content-length": "%d" % (len(reqData))
    }

    req = urllib2.Request(reqUrl, reqData, reqHeaders)
    try:
        response = urllib2.urlopen(req)
    except URLError, (e):
        print "CRITICAL - %s" % (str(e)[:60])
        sys.exit(2)

    try:
        json_response = simplejson.loads(response.read())
    except ValueError:
        print "CRITICAL - Invalid response from server"
        sys.exit(2)

    message = None
    if 'result' in json_response:
        message = json_response['result']
    elif 'error' in json_response:
        auth_message = json_response['error']
        if 'message' in auth_message:
            message = auth_message['message']

    if (message != None):
        if (message == True):
            print "OK - User authenticated"
            sys.exit(0)
        else:
            print "CRITICAL - %s" % (message[:60])
            sys.exit(2)
    else:
        print "UNKNOWN - Unable to verify authentication due to some unknown reason"
        sys.exit(3)
