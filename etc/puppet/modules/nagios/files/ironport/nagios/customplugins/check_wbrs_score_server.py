#!/usr/bin/python26

import pickle
import socket
import struct
import traceback

class WBRSScoreServer:
    def __init__(self, server, port):
        self.server = server
        self.port = port

    def connect(self):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect((self.server, self.port))

    def close(self):
        self.socket.close()

    def check_url_score(self, url):
        url_size = len(url)
        # The query is formatted as a 4 byte integer that explains the
        # size of the url being queried followed directly by the url
        # itself.
        query = struct.pack('i',url_size) + url
        self.connect()
        self.socket.send(query)
        # First we get back the size of the returned pickled object as
        # a 4 byte integer.
        response = self.socket.recv(4)
        size = struct.unpack('i', response)[0]
        # Now we get the data itself, a pickled object
        data = self.socket.recv(size)
        self.close()
        # Unpickle the object to get at the actual objects.
        object = pickle.loads(data)
        return object[0]['score']

if __name__ == '__main__':
    import optparse
    import sys
    usage = "usage: %prog [options] url"
    opt_parser = optparse.OptionParser(usage=usage)
    opt_parser.add_option('-H', '--host', help='Host to query.')
    opt_parser.add_option('-p', '--port', default=8081, type='int',
            help='Server port to connect to.  Default 8081.')
    opt_parser.add_option('-w', '--warning', type='float',
            help="Warning threshold for score.")
    opt_parser.add_option('-c', '--critical', type='float',
            help="Critical threshold for score.")

    try:
        (opt, args) = opt_parser.parse_args()
        url = args[0]
    except optparse.OptParseError:
        print "CRITICAL - Invalid commandline arguments."
        opt_parser.print_help()
        traceback.print_exc()
        sys.exit(2)
    except IndexError:
        print "CRITICAL - Must give a url to check."
        opt_parser.print_help()
        sys.exit(2)

    if opt.host == None:
        print "CRITICAL - Must specify a host with -H."
        opt_parser.print_help()
        sys.exit(2)

    server = WBRSScoreServer(opt.host, opt.port)

    try:
        score = server.check_url_score(url)
    except socket.gaierror:
        print "CRITICAL - Could not lookup server %s." % (opt.host)
        sys.exit(2)
    except socket.error:
        print "CRITICAL - Could not connect to WBRS score server " \
              "at %s:%d." % (opt.host, opt.port)
        sys.exit(2)
    except struct.error:
        print "CRITICAL - WBRS server returned invalid (likely empty) response"
        sys.exit(2)

    if not opt.critical == None and score < opt.critical:
        print "CRITICAL - %s has a score lower than %-.2f. " \
              "Critical threshold: %-.2f." % (url, score, opt.critical)
        sys.exit(2)
    if not opt.warning == None and score < opt.warning:
        print "WARNING - %s has a score lower than %-.2f. " \
              "Warning threshold: %-.2f." % (url, score, opt.warning)
        sys.exit(1)

    # This script assumes that the url you're monitoring should never
    # return a score of None.
    if score == None:
        print "CRITICAL - Received a score of 'None' for %s." % (url)
        sys.exit(2)

    print "OK - %s has a score of %-.2f." % (url, score)
