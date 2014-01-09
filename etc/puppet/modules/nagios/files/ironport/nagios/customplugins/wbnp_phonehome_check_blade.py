#!/usr/bin/python26
"""
WBNP Phonehome Nagios plugin.

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/wbnp_phonehome_check_blade.py#1 $

:Author: mskotyn
"""


import gzip
import os
import socket
import traceback


from cStringIO import StringIO
from httplib import BadStatusLine
from httplib import HTTPResponse
from httplib import HTTPSConnection


import base_nagios_plugin as nagios_plugins

class PhonehomeHTTPResponse(HTTPResponse):
    """
    Modification of HTTPResponse to serve Phonehome response started from POST.
    """
    def _read_status(self):
        # Initialize with Simple-Response defaults
        line = self.fp.readline()
        if self.debuglevel > 0:
            print "reply:", repr(line)
        if not line:
            # Presumably, the server closed the connection before
            # sending a valid response.
            raise BadStatusLine(line)
        if line[:4] == 'POST':
            [method, srv_path, version] = line.split(None, 2)
            status = 200
            reason = 'OK'
        else:
            try:
                [version, status, reason] = line.split(None, 2)
            except ValueError:
                try:
                    [version, status] = line.split(None, 1)
                    reason = ""
                except ValueError:
                    # empty version will cause next test to fail and status
                    # will be treated as 0.9 response.
                    version = ""
        if not version.startswith('HTTP/'):
            if self.strict:
                self.close()
                raise BadStatusLine(line)
            else:
                # assume it's a Simple-Response from an 0.9 server
                self.fp = LineAndFileWrapper(line, self.fp)
                return "HTTP/0.9", 200, ""

        # The status code is a three-digit number
        try:
            status = int(status)
            if status < 100 or status > 999:
                raise BadStatusLine(line)
        except ValueError:
            raise BadStatusLine(line)
        return version, status, reason

class PhonehomeHTTPSConnection(HTTPSConnection):
    response_class = PhonehomeHTTPResponse


def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    WBNP Phonehome state, and return it.
    """

    optp = nagios_plugins.NagiosOptionParser()

    optp.add_option('-v', '--verbosity', dest='verbosity',
                    action='store', type='int', help='Verbosity: 0-2')

    optp.add_option('-H', '--host-name', dest='host_name', metavar="HOST_NAME",
                    action='store', type='string',
                    help='host of the phonehome server to check status for')

    optp.add_option('-p', '--base-port', dest='base_port', metavar="BASE_PORT",
                    action='store', type='int',
                    help='port there is phonehome server listening')

    optp.add_option('-t', '--timeout', dest='timeout', metavar='TIMEOUT',
                    type='float', action='store',
                    help='time to wait of response')

    optp.add_option('--ping-req', dest='ping_req', action='store',
                    metavar='PING_REQ',
                    type='string', help='request string to send to the server')

    optp.add_option('--ping-resp', dest='ping_resp', action='store',
                    metavar='PING_RESP',
                    type='string', help='response string expected from the server')

    optp.set_defaults(ping_req='li20001e0:i3ee',
                      ping_resp='li20002ee',
                      port=443,
                      timeout=5.0,
                      verbosity=0)

    return optp

def process_args(optp):
    """
    Given an option parser, optp, execute it and check options for consistency.

    :return: opt, args
    """
    (opt, args) = optp.parse_args()

    if opt.verbosity not in (0, 1, 2):
        raise nagios_plugins.UsageError('Verbosity must be 0, 1, or 2')

    if not opt.host_name:
        raise nagios_plugins.UsageError('host is required')

    return opt, args

def build_result_msg(result, opt, err='', response=''):
    """
    Build a result message based on the verbosity level
    """
    suffix = ''
    if result == nagios_plugins.RESULT_OK:
        suffix = 'Received expected response.'
    else:
        suffix = err
    if opt.verbosity > 0:
        suffix += ' Host: %s, port: %s' % (opt.host_name, str(opt.base_port))
    if opt.verbosity == 2 and response != '':
        suffix += '\nRequest: %s, expected response: %s, received response: %s' % (opt.ping_req, opt.ping_resp, response)
    return '%s' % (suffix,)

def ping_phonehome(opt, args):
    result = nagios_plugins.RESULT_WARNING
    err = ''
    data = ''
    try:
        socket.setdefaulttimeout(opt.timeout)
        req_data = opt.ping_req
        conn = PhonehomeHTTPSConnection(opt.host_name, opt.base_port)
        conn.request('POST', '/phonehome', req_data)
        resp = conn.getresponse()
        data = resp.read()
        headers = resp.getheaders()

        try:
            if ('x-gzip', 'true') in headers:
                io = StringIO()
                io.write(data)
                io.seek(0)
                gz = gzip.GzipFile(fileobj = io, mode = 'r')
                data = gz.read()
            if data.startswith('data='):
                data = data[len('data='):]
            if data == opt.ping_resp:
                result = nagios_plugins.RESULT_OK
            else:
                result = nagios_plugins.RESULT_WARNING
                err = 'Wrong response received.'
        except Exception, e:
            result = nagios_plugins.RESULT_WARNING
            err = 'Wrong response received.'

    except(socket.timeout, socket.error), e:
        result = nagios_plugins.RESULT_WARNING
        if e[0] == 22:
            err = 'Network error: Connection refused.'
        else:
            err = 'Network error: %s.' % str(e)
    except Exception, e:
        result = nagios_plugins.RESULT_WARNING
        err = 'Network error: %s.' % str(e)


    msg = build_result_msg(result, opt, err, data)

    return result, msg
    

def main():
    optp = make_option_parser()
    try:
        opt, args = process_args(optp)
    except nagios_plugins.UsageError, e:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(e))

    try:
        result, msg = ping_phonehome(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
     main()
