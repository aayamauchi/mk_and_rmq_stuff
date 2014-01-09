#!/usr/local/bin/python
"""
RPC Ping Nagios plugin.

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/rpc_ping.py#2 $

:Author: mskotyn
"""

import cPickle
import socket
import sys
import time
import traceback

from threading import RLock

import base_nagios_plugin as nagios_plugins

class ConnectionError(Exception):
    pass

class RPCError(Exception):
    pass

class FastRPCClient:

    """rpc client.
    client blocks when making an RPC request; is resumed when
    the reply is returned."""

    DEBUG = 0

    # override these to control retry/timeout schedule
    _num_retries = 3
    _retry_timeout = 3

    def __init__ (self, addr):
        """
        :param addr: (IP, port)
        """
        self.addr = addr

        self.conn = None

        # 0: not connected
        # 1: connecting
        # 2: connected
        self.connected = 0

        self.__lock = RLock()

    def close(self):
        if self.connected and self.socket:
            self.socket.close()
            self.connected = 0

    def _connect (self):
        if type(self.addr) is type(''):
            self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        else:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.connect(self.addr)
        self.connected = 2

    def get_connected (self):
        """
        try to connect
        """
        if self.connected == 0:
            self.connected = 1
            for i in range (self._num_retries):
                try:
                    self._connect()
                except socket.error, e:
                    # Connection failed so wait for a while before the next try
                    print >> sys.stderr, 'Connection to %s failed. Sleep for'\
                                         ' %d seconds and retry...' % \
                                         (self.addr, self._retry_timeout)
                    time.sleep(self._retry_timeout)
                except:
                    self.connected = 0
                    raise
                else:
                    return self.connected

            # ok, we give up!
            # fail any pending requests
            self.connected = 0
            raise ConnectionError, '(%s:%s) is unreachable.' % self.addr

        return self.connected

    def __request (self, path, params):
        """
        send request and get answer

        :param path: RPC call path
        :param params: paramters

        :return: the result returned by server
        :exception: socket.error when not in forever mode
        """
        self.__lock.acquire()
        try:
            if self.connected != 2:
                if self.connected == 0:
                    self.get_connected()

                if self.connected != 2:
                    return None

            packet = cPickle.dumps((0, path, params))
            data = []
            data.append('%08x' % (len(packet)))
            data.append(packet)
            try:
                self.socket.sendall(''.join(data))
                reply = self.socket.recv(8, socket.MSG_WAITALL)
                if reply == '':
                    raise EOFError
                size = int (reply, 16)
                size_left = size
                packet = ''
                while size_left > 0:
                    temp_packet = self.socket.recv(size_left)
                    if temp_packet == '':
                        raise EOFError
                    packet += temp_packet
                    size_left -= len(temp_packet)
                id, error, result = cPickle.loads (packet)

            except (socket.error, OSError, EOFError):
                self.connected = 0
                self.socket.close()
                raise

            if error:
                raise RPCError, error
            else:
                return result
        finally:
            self.__lock.release()


    def request (self, path, params):
        """
        wrapper of __request()
        """
        return self.__request(path, params)


def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    state, and return it.
    """

    optp = nagios_plugins.NagiosOptionParser()

    optp.add_option('-v', '--verbosity', dest='verbosity',
                    action='store', type='int', help='Verbosity: 0-2')

    optp.add_option('-H', '--host-name', dest='host_name', metavar="HOST_NAME",
                    action='store', type='string',
                    help='host of the rpc server to check status for')

    optp.add_option('-p', '--base-port', dest='base_port', metavar="BASE_PORT",
                    action='store', type='int',
                    help='port there is rpc server listening')

    optp.add_option('-t', '--timeout', dest='timeout', metavar='TIMEOUT',
                    type='float', action='store',
                    help='time to wait of response')

    optp.add_option('--req-path', dest='req_path', action='store',
                    metavar='REQUEST_PATH',
                    type='string', help='Path to remote called procedure.')

    optp.add_option('--req-args', dest='req_args', action='store',
                    metavar='REQUEST_ARGS',
                    type='string', help="""Parameters of remote called procedure.
If a remote called procedure require specific type of the parameter,
use a Python's type conversion function. Example:
-req-args "int(10) float(2.5) dict({'a':'c','e':3}) list(('a','b',3)) tuple((2,3,'a'))"
Default type of parameter is string.""")

    optp.add_option('--resp', dest='resp', action='store',
                    metavar='EXPECTED_RESP',
                    type='string', help='response string expected from the server')

    optp.set_defaults(base_port=15000,
                      req_path='ping',
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
    if result == nagios_plugins.RESULT_OK and err == '':
        suffix = 'Received expected response.'
    else:
        suffix = err
    if opt.verbosity > 0:
        suffix += ' Host: %s, port: %s' % (opt.host_name, str(opt.base_port))
    if opt.verbosity == 2 and response != '':
        suffix += '\nExpected response: %s, received response: %s' % (opt.resp, response)

    return '%s' % (suffix,)

def args_eval(value):
    types = ['int(', 'long(', 'float(', 'str(', 'tuple(', 'list(', 'dict(',
             'chr(', 'unichr(', 'ord(', 'hex(', 'oct(']
    for expected_type in types:
        if value.startswith(expected_type):
            return eval(value)
    return value

def ping_rpc(opt, args):
    result = nagios_plugins.RESULT_WARNING
    err = ''
    data = ''
    socket.setdefaulttimeout(opt.timeout)
    try:
        addr = (opt.host_name, opt.base_port)
        client = FastRPCClient(addr)
        if opt.req_args is not None:
            req_args = tuple(map(args_eval, opt.req_args.split()))
        else:
            req_args = ()
        req_path = tuple(opt.req_path.split())
        data = client.request(req_path, req_args)
        if opt.resp is not None:
            if str(data) == opt.resp:
                result = nagios_plugins.RESULT_OK
            else:
                result = nagios_plugins.RESULT_WARNING
                err = 'Wrong response received.'
        else:
            # Skip response check if opt.resp is not defined
            result = nagios_plugins.RESULT_OK
            err = 'Ping successful. Response check skipped.'
    except ConnectionError, e:
        result = nagios_plugins.RESULT_CRITICAL
        err = 'Connection failed. Reason: %s' % str(e)
    except socket.timeout, e:
        result = nagios_plugins.RESULT_CRITICAL
        err = 'Connection failed. Reason: timeout'

    msg = build_result_msg(result, opt, err, data)

    return result, msg

def main():
    optp = make_option_parser()
    try:
        opt, args = process_args(optp)
    except nagios_plugins.UsageError, e:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(e))

    try:
        result, msg = ping_rpc(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
