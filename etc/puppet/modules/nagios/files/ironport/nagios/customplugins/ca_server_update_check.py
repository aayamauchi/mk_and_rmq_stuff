#!/usr/bin/python26
"""
Check CA Server update status

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/ca_server_update_check.py#1 $

:Author: vkuznets
"""

import cPickle
import socket
import traceback

from threading import RLock

import base_nagios_plugin as nagios_plugins

UPDATE_STATUS_METHOD = 'get_update_status'

# updater constants
UPDATE_REQUIRED         = 103
NO_UPDATE_AVAILABLE     = 104
LATEST_UPDATE_INSTALLED = 105


class ConnectionError(Exception):
    pass

class ServerUnreachable(Exception):
    pass

class RPCError(Exception):
    pass

class simple_fastrpc_client:

    """rpc client.
    client blocks when making an RPC request; is resumed when
    the reply is returned."""

    DEBUG = 0

    # override these to control retry/timeout schedule
    _num_retries = 3
    _retry_timeout = 2
    _forever_retry_timeout = 10

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
                    raise ConnectionError('socket.error [%s]' % (e,))
                except:
                    self.connected = 0
                    raise
                else:
                    return self.connected

            # ok, we give up!
            # fail any pending requests
            self.connected = 0
            # P ('RPC: server unreachable\n')
            raise ServerUnreachable, '(%s:%s) is unreachable' % self.addr

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

    optp.set_defaults(base_port=23000,
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

def check_update_status(opt, args):
    """
    Performs CA Server update status check
    """
    result = nagios_plugins.RESULT_WARNING
    msg = ''
    socket.setdefaulttimeout(opt.timeout)
    try:
        addr = (opt.host_name, opt.base_port)
        client = simple_fastrpc_client(addr)
        response = client.request((UPDATE_STATUS_METHOD,), ())
        statuses = []
        for component, (code, _) in response.iteritems():
            statuses.append(code)
            if code == UPDATE_REQUIRED:
                msg += ' Update required for `%s` component.' % (component,)
            elif code == NO_UPDATE_AVAILABLE:
                msg += ' No update available for `%s` component.' % (component,)

        if UPDATE_REQUIRED in statuses:
            result = nagios_plugins.RESULT_CRITICAL
        elif NO_UPDATE_AVAILABLE in statuses:
            result = nagios_plugins.RESULT_WARNING
        else:
            result = nagios_plugins.RESULT_OK
            msg = 'The latest updates already installed.'
            
    except (ServerUnreachable, ConnectionError), e:
        result = nagios_plugins.RESULT_CRITICAL
        msg = 'Connection failed. Reason: %s' % str(e)
    except socket.timeout, e:
        result = nagios_plugins.RESULT_CRITICAL
        msg = 'Connection failed. Reason: timeout'
    return result, msg

def main():
    optp = make_option_parser()
    try:
        opt, args = process_args(optp)
    except nagios_plugins.UsageError, e:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(e))

    try:
        result, msg = check_update_status(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
