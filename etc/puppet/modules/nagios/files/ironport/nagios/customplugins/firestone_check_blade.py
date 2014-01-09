#!/usr/bin/python26
"""
Firestone Remote SDK Server Check

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/firestone_check_blade.py#1 $

:Author: ydidukh
"""
import struct
import socket

import base_nagios_plugin as nagios_plugins

HOST = 'fs.fastdatatech.com'
PORT = 4320
BUF_LEN = 4096
TIMEOUT = 60

statusMap = {
    nagios_plugins.RESULT_OK: (),
    nagios_plugins.RESULT_WARNING: (),
    nagios_plugins.RESULT_CRITICAL: (),
    nagios_plugins.RESULT_SCRIPT_ERROR: ()
    }

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    firestone remote server responds with proper categories
    """
    optp = nagios_plugins.NagiosOptionParser()
    optp.add_option('-v', '--verbosity', dest='verbosity',
                                action='store', type='int', help='Verbosity: 0-2. Default: %default')
    optp.add_option('-H', '--hostname', dest='hostname',
                    action='store', help='Firestone Hostname. Default: %default')
    optp.add_option('-p', '--port', dest='port',type='int',
                    action='store', help='Port number. Default: %default')
    optp.add_option('-u', help='URL with expected category. This option is multiple.',
                    action='append', dest='urls',
                    metavar='URL:CATEGORY_NUMBER')

    optp.add_option('-f',
                    help='Filename where URLs and their category numbers are located. ' + \
                         'File should be in plain text form where each line given in format: "url category_number".',
                    action='store', dest='urls_filename')

    optp.set_defaults(verbosity=0,
                      hostname=HOST,
                      port=PORT)
    return optp

def _build_request(url):
    REQUEST_HEADER = 'U\x18\x00\x00\x00\x00\x00\x00\x01\x00\xff\xff\xff\x00\x00e\x00'
    request = REQUEST_HEADER
    request += struct.pack('b', len(url))
    for char in url:
        request += struct.pack('c', char)
    request += '\x00'
    return request


def _decode_response(response):
    response_code = (struct.unpack('b', response[1])[0] >> 2) & 0x03
    category_number = struct.unpack('H', response[6:8][::-1])[0]
    return (response_code, category_number)

def _get_response(request):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(TIMEOUT)
    try:
        sock.connect((HOST, PORT))
        bytes_sent = sock.send(request)
        while len(request) > bytes_sent:
            bytes_sent += sock.send(request[bytes_sent:])

        response = sock.recv(BUF_LEN)
    except socket.error, e:
        return None, [str(e)]
    return response, []

def get_category_for_url(url):
    err_code = category = None
    request = _build_request(url)
    raw_response, errors = _get_response(request)
    if not errors:
        err_code, category = _decode_response(raw_response)
    return err_code, category, errors

def do_calc_matches(urls):
    not_matched = []
    with_errors = []
    matched_cnt = 0
    for url, expected_category in urls:
        err_code, current_category, errors = get_category_for_url(url)
        if err_code or errors:
            with_errors.append( (url, err_code, errors) )
        elif expected_category != current_category:
            not_matched.append( (url, expected_category, current_category) )
        else:
            matched_cnt += 1
    return matched_cnt, not_matched, with_errors

def build_result_msg(verbosity, matched_cnt=None, with_errors=None, not_matched=None):
    msg = 'Matched: %d, Not Matched: %d, With Errors: %d' % (matched_cnt or 0,
                                                             len(not_matched or []),
                                                             len(with_errors or []))
    if verbosity < 2:
        return msg
    elif verbosity == 2:
        if not_matched or with_errors:
            msg += '\n\n'
        if len(not_matched or []):
            msg += 'There is category changes for the following URL(s):'
            for url, exp_cat, curr_cat in not_matched:
                msg += '\nURL: %s\n' % url
                msg += 'Current Category Number:  %s\n' % curr_cat
                msg += 'Expected Category Number: %s\n\n' % exp_cat
        if len(with_errors or []):
            msg += 'Unable to get category number for the following URL(s):'
            for url, err_code, exceptions in with_errors:
                msg += '\nURL: %s\n' % url
                msg += 'Response Code: %s\n' % err_code
                if not exceptions:
                    exc_msg = 'None'
                else:
                    exc_msg = ', '.join(['"%s"' % x for x in exceptions])
                msg += 'Exception(s): %s\n' % exc_msg
    else:
        assert (False, 'Invalid verbosity level')
    return msg


def process_args(optp):
    return optp.parse_args()

def main():
    global HOST, PORT
    optp = make_option_parser()
    try:
        opt, _ = process_args(optp)
    except nagios_plugins.UsageError, e:
        msg = 'Exception: %s' % str(e)
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, msg)

    if opt.hostname:
        HOST = opt.hostname
    if opt.port:
        PORT = opt.port

    urls = []
    try:
        for url_with_cat in (opt.urls or []):
            category = url_with_cat.strip().split(':')[-1]
            category = int(category)
            url = ':'.join(url_with_cat.strip().split(':')[:-1])
            urls.append((url, category))
        if opt.urls_filename:
            fh = open(opt.urls_filename, 'r')
            for url_with_cat in fh.readlines():
                url, category = url_with_cat.strip().split()
                urls.append((url, int(category)))
            fh.close()
    except Exception ,e:
        msg = 'Exception: %s' % str(e)
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, msg)

    matched_cnt, not_matched, with_errors = do_calc_matches(urls)
    if len(urls) == 0:
        result = nagios_plugins.RESULT_WARNING
    elif matched_cnt == len(urls):
        result = nagios_plugins.RESULT_OK
    else:
        result = nagios_plugins.RESULT_CRITICAL
    msg = build_result_msg(opt.verbosity,
                           matched_cnt = matched_cnt,
                           with_errors = with_errors,
                           not_matched = not_matched)
    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()

