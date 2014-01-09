#!/usr/bin/python26
"""
DEX Cluster workers number check Nagios plugin.

For more information:
http://eng.ironport.com/docs/is/proj/cinema/eng/ds/monitoring_changes-ds.rst#dex-cluster-monitoring-changes

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/dex_workers_num_check.py#1 $

:Author: vscherb
"""

import sys
import traceback
import MySQLdb
import cPickle
import socket
import base_nagios_plugin as nagios_plugins

from optparse import OptionGroup
from threading import RLock

DEFAULT_WARN_THRESHOLD     = 25 # %
DEFAULT_CRITICAL_THRESHOLD = 50 # %
DEFAULT_BASE_PORT          = 10000
DEFAULT_WORKERS_NUM        = 4

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
    feeds getter, and return it.
    """
    optp = nagios_plugins.make_option_parser()

    optp.remove_option('-d')
    optp.remove_option('-D')
    optp.remove_option('--db-user')
    optp.remove_option('--db-passwd')
    
    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Percentage of DEX workers gone down for a warning. ' \
                    'Default: %s' % DEFAULT_WARN_THRESHOLD

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Percentage of DEX workers gone down for a critical error. ' \
                    'Default: %s' % DEFAULT_CRITICAL_THRESHOLD

    optp.add_option(
        "-H", "--host-name", metavar="HOST_NAME", action="store",
        type="string", dest="host_name",
        help="host-name to check DEX cluster workers number on. " \
             "Default: current host name %s" % socket.gethostname())

    optp.add_option(
        "-p", "--base-port", metavar="BASE_PORT", action="store",
        type="int", dest="base_port",
        help="base DEX scheduler rpc port. " \
             "Default: %s" % DEFAULT_BASE_PORT)

    optp.add_option(
        "-W", "--workers-num", metavar="WORKERS_NUM", action="store",
        type="int", dest="workers_num",
        help="the number of set up DEX cluster workers. " \
             "Default: %s" % DEFAULT_WORKERS_NUM)

    optp.set_defaults(warn_threshold=DEFAULT_WARN_THRESHOLD,
                      critical_threshold=DEFAULT_CRITICAL_THRESHOLD,
                      host_name=socket.gethostname(),
                      base_port=DEFAULT_BASE_PORT,
                      workers_num=DEFAULT_WORKERS_NUM,
                      db_server='dummy',
                      db_name='dummy')

    return optp


def build_result_msg(opt, result, num_running_workers):
    """
    Build a result message based on the verbosity level
    """

    msg = 'Number of running DEX workers (%s)' % (num_running_workers,)

    if result == nagios_plugins.RESULT_CRITICAL:
        msg = 'Too many DEX workers gone down! %s is critically low.' % msg

    elif result == nagios_plugins.RESULT_WARNING:
        msg += ' is low.'

    else:
        msg += ' looks ok.'
    
    if opt.verbosity < 2:
        pass
    elif opt.verbosity == 2:

        down_workers_num = opt.workers_num - num_running_workers
        down_workers_pct = 100.0 * down_workers_num/opt.workers_num
        
        msg += ' %2.2f%% (%s) of set up workers num (%s) gone down' % \
               (down_workers_pct, down_workers_num, opt.workers_num)

        if result == nagios_plugins.RESULT_CRITICAL:
            msg += ': this exeeds the critical_threshold of %s%%.' % \
                   (opt.critical_threshold,)

        elif result == nagios_plugins.RESULT_WARNING:
            msg += ': this exeeds the warn_threshold of %s%%.' % \
                   (opt.warn_threshold,)

        else:
            msg += ' (warn_threshold is %s%%).' % \
                   (opt.warn_threshold,)
    else:
        assert(False, "Invalid verbosity")

    return msg


def check_dex_workers_num_status(opt, args):
    
    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    
    try:
        addr = (opt.host_name, opt.base_port)
        rpc_client = simple_fastrpc_client(addr)
    except Exception, e:
        msg = 'Failed to initialize RPC-client'
        if opt.verbosity == 2:
            msg += ': %s' % (e,)
        return result, msg

    try:
        running_workers = rpc_client.request(('get_all_workers',),())
        num_running_workers = len(running_workers)
    except Exception, e:
        msg = 'Not able to fetch workers information'
        if opt.verbosity == 2:
            msg += ': %s' % (e,)
        return nagios_plugins.RESULT_CRITICAL, msg
    
    down_workers_pct = 100.0 * (1 - 1.0*num_running_workers/opt.workers_num)

    if down_workers_pct > opt.critical_threshold:
        result = nagios_plugins.RESULT_CRITICAL

    elif down_workers_pct > opt.warn_threshold:
        result = nagios_plugins.RESULT_WARNING

    else:
        result = nagios_plugins.RESULT_OK

    msg = build_result_msg(opt, result, num_running_workers)

    return result, msg

def main():
    optp = make_option_parser()
    try:
        opt, args = nagios_plugins.process_args(optp)
    except nagios_plugins.UsageError, e:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(e))
        
    try:
        result, msg = check_dex_workers_num_status(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()

