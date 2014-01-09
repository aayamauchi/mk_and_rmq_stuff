#!/usr/bin/python26
"""
Score Server Nagios plugin.

For more information:
http://eng.ironport.com/docs/is/web_reputation/1_3/eng/ER2/score_server-ds.rst#score-server-nagios-plugin

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/cinema_score_server_check.py#1 $

:Author: ydidukh
"""
import cPickle
import sys
import socket
import struct
import types
import traceback
import pprint
import operator

import time
from datetime import datetime

import base_nagios_plugin as nagios_plugins

MAX_TIMEOUT = 5
verbosity = 2

# Constant variables taken from common/wbrs/score_server/constants.py file.
GET_SCORER_UPDATE_STATUS = 5
GET_WBRS_TIMESTAMPS = 3
GET_FULL_WBRS_SCORED_INFO = 2

# Errors
NO_ERRORS = 0
SIMPLEWBRSD_START_ERR = 5
SCORER_ERROR = 10
UPDATE_ERROR = 20
PARAMETERS_PROCESSING_ERROR = 30
INTERNAL_ERROR = 40

RESPONSE_PARSE_ERROR = 101
TIMEOUT_ERROR = 105
SOCKET_ERROR = 106

WARN_THRESHOLD_ERR = 201
CRIT_THRESHOLD_ERR = 202
UNKNOWN_ERROR = 203
USAGE_ERROR = 204

verbosityMap = {
    (NO_ERRORS,): { \
        0: 'Everything is cool',
        1: 'Database version timestamps: %s',
        2: 'Database version timestamps: %s, SimpleWBRSD last update time: %s',},
    (WARN_THRESHOLD_ERR,): { \
        0: 'SimpleWBRSD last update time for %s db: %s',
        1: 'SimpleWBRSD last update time for %s db is %s but defined threshold is %s',
        2: 'SimpleWBRSD last update time for %s db is %s but defined threshold is %s.'
           '\nLast processed database timestamps are: %s. Error message: %s'
        },
    (CRIT_THRESHOLD_ERR,): {
        0: 'SimpleWBRSD last update time for %s db: %s',
        1: 'SimpleWBRSD last update time for %s db is %s but defined threshold is %s',
        2: 'SimpleWBRSD last update time for %s db is %s but defined threshold is %s.'
           '\nLast processed database timestamps are: %s. Error message: %s',},
    (SIMPLEWBRSD_START_ERR, UPDATE_ERROR, SCORER_ERROR): {
        0: 'Score Server error',
        1: 'Score Server\'s SimpleWBRSD component error',
        2: 'Score Server\'s SimpleWBRSD component error. Error message: %s'
        },
    (RESPONSE_PARSE_ERROR, TIMEOUT_ERROR, PARAMETERS_PROCESSING_ERROR, UNKNOWN_ERROR): {
        0: 'Score Server error',
        1: 'Score Server error.',
        2: 'Score Server error. Error message: %s',
        },
    (SOCKET_ERROR,): {
        0: 'Unable to connect to the Score Server instance',
        1: 'Unable to connect to the Score Server instance',
        2: 'Unable to connect to the Score Server instance. Error message: %s',
        },
    (USAGE_ERROR,): {
        0: 'Wrong command line parameters',
        1: 'Wrong command line parameters',
        2: 'Usage error: Wrong command line parameters. Error message: %s',
        }
    }

statusMap = {
    nagios_plugins.RESULT_OK: (NO_ERRORS,),
    nagios_plugins.RESULT_WARNING: (WARN_THRESHOLD_ERR,),
    nagios_plugins.RESULT_CRITICAL: (SOCKET_ERROR,
                                     RESPONSE_PARSE_ERROR,
                                     TIMEOUT_ERROR,
                                     PARAMETERS_PROCESSING_ERROR,
                                     SIMPLEWBRSD_START_ERR,
                                     UPDATE_ERROR,
                                     SCORER_ERROR,
                                     CRIT_THRESHOLD_ERR,
                                     UNKNOWN_ERROR),
    nagios_plugins.RESULT_SCRIPT_ERROR: (USAGE_ERROR,)
    }

known_errors = reduce(operator.add, statusMap.values())

errorTab = {
        # Client side error codes
    RESPONSE_PARSE_ERROR: "Unable to parse received response. Broken data.",
    TIMEOUT_ERROR: "The operation timed out.",
        # Response error codes,
    SIMPLEWBRSD_START_ERR: "Unable to start SimpleWBRSD daemon.",
    UPDATE_ERROR: "SimpleWBRSD update WBRS databases error.",
    SCORER_ERROR: "Scoring error.",
    PARAMETERS_PROCESSING_ERROR: "Parameters processing error.",
    UNKNOWN_ERROR: "Received unknown error code %s.",

    WARN_THRESHOLD_ERR: "Warning threshold error.",
    CRIT_THRESHOLD_ERR: "Critical threshold error.",
    }


def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    score server's state, and return it.
    """
    optp = nagios_plugins.NagiosOptionParser()
    optp.add_option('-v', '--verbosity', dest='verbosity',
                                action='store', type='int', help='Verbosity: 0-2')
    optp.add_option('-w', '--warn-threshold', dest='warn_threshold',
                    action='store', type='string',
                    help=
                    'Format: -w <int>[,<int>,<int>]. ' \
                    'Warning threshold (in seconds) for SimpleWBRSD\'s time period after last successsful ' \
                    'update till now. Specified for ip and prefix databases (if only one ' \
                    'value passed) or for all databases (if 3 values passed). Default: -w 1800.')

    optp.add_option('-c', '--critical-threshold', dest='critical_threshold',
                    action='store', type='string',
                    help=
                    'Format: -c <int>[,<int>,<int>]. ' \
                    'Critical threshold (in seconds) for SimpleWBRSD\'s time period after last successsful ' \
                    'update till now. Specified for ip and prefix databases (if only one ' \
                    'value passed) or for all databases (if 3 values passed). Default: -c 3600.')
    optp.add_option('-s', '--socket-path', dest='sock_path',
                    action='store', help='Unix socket path')
    optp.add_option('-H', '--tcp-host', dest='tcp_host',
                    action='store', help='TCP host')
    optp.add_option('-p', '--tcp-port', dest='tcp_port',type='int',
                    action='store', help='TCP port')

    optp.set_defaults(verbosity=0,
                      warn_threshold='1800',
                      critical_threshold='3600')
    return optp

def process_args(optp):
    """
    Given an option parser, optp, execute it and check options for consistency.

    :return: opt, args
    """
    global verbosity
    global w_ip, w_prefix, w_rule
    global c_ip, c_prefix, c_rule

    (opt, args) = optp.parse_args()

    if opt.verbosity not in (0, 1, 2):
        raise nagios_plugins.UsageError('Verbosity must be 0, 1, or 2')
    verbosity = opt.verbosity

    try:
        warns = [int(w.strip()) for w in opt.warn_threshold.split(',')]
    except ValueError:
        raise nagios_plugins.UsageError('warning_threshold must be passed in format \'-w <int>[,<int>,<int>]\'.')

    if len(warns) == 1:
        w_ip = w_prefix = warns[0]
        w_rule = None
    elif len(warns) > 1:
        w_ip, w_prefix = warns[:2]
        w_rule = (len(warns) == 3 and warns[2]) or None

    try:
        crit = [int(c.strip()) for c in opt.critical_threshold.split(',')]
    except ValueError:
        raise nagios_plugins.UsageError('critical_threshold must be passed in format \'-c <int>[,<int>,<int>]\'.')

    if len(crit) == 1:
        c_ip = c_prefix = crit[0]
        c_rule = None
    elif len(crit) > 1:
        c_ip, c_prefix = crit[:2]

        c_rule = (len(crit) == 3 and crit[2]) or None

    if not ((c_rule > w_rule or c_rule == w_rule == None) and c_prefix > w_prefix and c_ip > w_ip):
        raise nagios_plugins.UsageError('critical_threshold must be greater than warn_threshold (%s)' %
                         (opt.warn_threshold,))

    if (opt.sock_path and opt.tcp_host) or not ( (opt.tcp_host and opt.tcp_port) or opt.sock_path):
        raise nagios_plugins.UsageError('Socket or tcp connection type must be defined')

    return opt, args

def build_result_msg(error, insert_attrs=None, append_attrs=None):
    """
    Build a result message based on the verbosity level
    """
    global verbosity

    if not insert_attrs:
        insert_attrs = []
    if not append_attrs:
        append_attrs = []

    for status in statusMap:
        if error in statusMap[status]:
            break

    err_code = error
    if err_code not in known_errors:
        err_code = UNKNOWN_ERROR
    msg = None
    for err_list in verbosityMap:
        if err_code in err_list:
            msg = verbosityMap[err_list][verbosity]

    if errorTab.has_key(error):
        insert_attrs.append(errorTab[error])

    if msg.count('%s'):
        msg = msg % tuple(insert_attrs[:msg.count('%s')])
    if verbosity > 1:
        msg += ' '.join(append_attrs)

    if err_code == UNKNOWN_ERROR:
        msg += ' Received unknown error code: %d' % error

    return status, msg


def send_command(opt, request):
    sock = None
    try:
        try:
            if opt.sock_path:
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                sock.connect(opt.sock_path)
            elif opt.tcp_host:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.connect((opt.tcp_host, opt.tcp_port))
            sock.settimeout(MAX_TIMEOUT)

            sock.send(request)
            resp_len = struct.unpack('i', sock.recv(4))[0]
            raw_response = cPickle.loads(sock.recv(resp_len))
            return raw_response
        except TypeError, e:
            result, msg = build_result_msg(RESPONSE_PARSE_ERROR)
            nagios_plugins.exitwith(result, msg)
        except socket.timeout:
            result, msg = build_result_msg(TIMEOUT_ERROR)
            nagios_plugins.exitwith(result, msg)
        except socket.error, e:
            result, msg = build_result_msg(SOCKET_ERROR, (str(e),))
            nagios_plugins.exitwith(result, msg)
    finally:
        if sock is not None:
            sock.close()


def check_score_server_status(opt, args):
    request = struct.pack('i', 1) + chr(GET_SCORER_UPDATE_STATUS)
    status, err_code = send_command(opt, request)
    if err_code != NO_ERRORS:
        return build_result_msg(err_code)

    try:
        simplewbrsd_failed = not (  status['ip']['status'] \
                                    and status['prefix']['status'] \
                                    and status['rule']['status'] )
    except:
        simplewbrsd_failed = True

    scorer_ok = False
    urls = ('http://www.google.com', 'http://ironport.com', 'http://yahoo.com')
    for url in urls:
        raw_params = {'url': url}
        params = cPickle.dumps(raw_params)
        params_len = struct.pack('i', len(params))
        request = struct.pack('i', 1) + chr(GET_FULL_WBRS_SCORED_INFO) + params_len + params
        score, err_code = send_command(opt, request)
        if err_code == NO_ERRORS:
            if score[0]['score'] is not None:
                scorer_ok = True
        else:
            return build_result_msg(err_code)

    if simplewbrsd_failed:
        update_dict = 'Update status dictionary:\n' + pprint.pformat(status)
        return build_result_msg(UPDATE_ERROR, append_attrs=[update_dict])

    request = struct.pack('i', 1) + chr(GET_WBRS_TIMESTAMPS)
    timestamps, err_code = send_command(opt, request)
    if err_code != NO_ERRORS:
        msg = '\nWBRS Database timestamps:' + pprint.pformat(timestamps)
        return build_result_msg(UPDATE_ERROR, append_attrs=[update_dict, msg])

    thresholds_list = [(CRIT_THRESHOLD_ERR, (('ip', c_ip), ('prefix', c_prefix), ('rule', c_rule))),
                       (WARN_THRESHOLD_ERR, (('ip', w_ip), ('prefix', w_prefix), ('rule', w_rule)))]

    update_times = {}
    for result, thresholds in thresholds_list:
        for db_type, t in thresholds:
            now = time.mktime(time.gmtime())
            last_update_time = status[db_type]['last_update_time']

            if type(last_update_time) == time.struct_time:
                last_update_time = time.mktime(last_update_time)
            update_times[db_type] = str(datetime.fromtimestamp(last_update_time))

            if now - last_update_time > t and t is not None:
                errs = [db_type,
                        str(datetime.fromtimestamp(last_update_time)),
                        str(datetime.fromtimestamp(now - t)),
                        str(timestamps),
                        ]
                return build_result_msg(result, errs)


    return build_result_msg(NO_ERRORS, (pprint.pformat(timestamps), pprint.pformat(update_times)))

def main():
    global verbosity
    optp = make_option_parser()
    try:
        opt, args = process_args(optp)
    except nagios_plugins.UsageError, e:
        result, msg = build_result_msg(USAGE_ERROR, [str(e)])
        nagios_plugins.exitwith(result, msg)

    try:
        result, msg = check_score_server_status(opt, args)
    except SystemExit:
        return
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()

