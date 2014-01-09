#!/usr/bin/python26
"""
FT Service check Nagios plugin.

usage: ft_service_check.py [options]

options:
  -h, --help            show this help message and exit
  -d DB_SERVER, --db-server=DB_SERVER
                        db-server to check status on
  -v VERBOSITY, --verbosity=VERBOSITY
                        Verbosity: 0-2
  -D DB_NAME, --db-name=DB_NAME
                        db-name to read from
  --db-user=DB_USER     User for db connection
  --db-passwd=DB_PASSWD
                        Passwd for db connection
  -A APP_NAME, --app-name=APP_NAME
                        FT application name
  -C CLUSTER_NAME, --cluster-name=CLUSTER_NAME
                        FT cluster name
  -S SERVICE_NAME, --rpc-service-name=SERVICE_NAME
                        FT RPCd service name
  -t TIMEOUT, --timeout=TIMEOUT
                        Connection timeout
  --rpc-method=RPC_METHOD
                        RPC method name
  --method-args=METHOD_ARGS
                        RPC method args(optional)
  --expected-resp=EXPECTED_RESP
                        Expected method response(optional)

Please refer to:
http://eng.ironport.com/docs/is/proj/snowmass/snowmass_monitoring.rst
for detailed information.

:Author: vkuznets
"""

import cPickle
import socket

import MySQLdb

import base_nagios_plugin as nagios_plugins


class RPCError(Exception):
    """
    Common RPC error
    """
    pass

class ConnectionError(Exception):
    """
    RPC connection error
    """
    pass

class ServerUnreachable(Exception):
    """
    The server is unreachable
    """
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

    def __init__ (self, addr, connect_timeout=None):
        """
        :param addr: (IP, port) 
        """
        self.addr = addr

        self.conn = None

        self.connect_timeout = connect_timeout

        # 0: not connected
        # 1: connecting
        # 2: connected
        self.connected = 0

    def close(self):
        if self.connected and self.socket:
            self.socket.close()
            self.connected = 0

    def _connect (self):
        if type(self.addr) is type(''):
            self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        else:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.settimeout(self.connect_timeout)
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

    def request (self, path, params):
        """
        send request and get answer

        :param path: RPC call path
        :param params: paramters

        :return: the result returned by server
        :exception: socket.error when not in forever mode
        """
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
            _, error, result = cPickle.loads (packet)

        except (socket.error, OSError, EOFError):
            self.connected = 0
            self.socket.close()
            raise

        if error:
            raise RPCError(error)
        else:
            return result



def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments
    """

    optp = nagios_plugins.make_option_parser()
    optp.add_option('-A', '--app-name', dest='app_name', action='store',
                    metavar='APP_NAME',
                    type='string', help='FT application name')
    optp.add_option('-C', '--cluster-name', dest='cluster_name', action='store',
                    metavar='CLUSTER_NAME',
                    type='string', help='FT cluster name')
    optp.add_option('-S', '--rpc-service-name', dest='service_name',
                    action='store', metavar='SERVICE_NAME', default='rpcd',
                    type='string', help='FT RPCd service name')
    optp.add_option('-t', '--timeout', dest='timeout',
                    action='store', metavar='TIMEOUT', default=5,
                    type='int', help='Connection timeout')
    optp.add_option('--rpc-method', dest='rpc_method', action='store',
                    metavar='RPC_METHOD',
                    type='string', help='RPC method name')
    optp.add_option('--method-args', dest='method_args', action='store',
                    metavar='METHOD_ARGS',
                    type='string', help='RPC method args(optional)')
    optp.add_option('--expected-resp', dest='expected_resp', action='store',
                    metavar='EXPECTED_RESP',
                    type='string', help='Expected method response(optional)')

    optp.remove_option('-w')
    optp.remove_option('-c')

    return optp

def process_args(optp):
    """
    Given an option parser, optp, execute it and check options for consistency.

    :return: opt, args
    """
    (opt, args) = optp.parse_args()

    if not opt.db_server:
        raise nagios_plugins.UsageError('db-server is required')

    if opt.verbosity not in (0, 1, 2):
        raise nagios_plugins.UsageError('Verbosity must be 0, 1, or 2')

    if not opt.db_name:
        raise nagios_plugins.UsageError('db_name is required')

    if not opt.app_name:
        raise nagios_plugins.UsageError('app_name is required')

    if not opt.cluster_name:
        raise nagios_plugins.UsageError('cluster_name is required')

    if not opt.rpc_method:
        raise nagios_plugins.UsageError('rpc_method is required')

    return opt, args


def check_db_schema(conn):
    """
    Performs DB schema check
    """
    result = nagios_plugins.RESULT_OK
    msg = 'OK'
    try:
        nagios_plugins.check_db_schema(conn,
                               'ft_node_status',
                               ('app_name', 'cluster_name', 'node_name',
                                'node_state', 'last_start_ts', 'last_hb_ts',
                                'hostname', 'pid', 'rpcd_host', 'rpcd_port',
                                'httpd_host', 'httpd_port'))
    except nagios_plugins.InvalidDBSchema, exc:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = str(exc)
    return result, msg


def get_rpcd_addr(conn, app_name, cluster_name, rpc_service_name):
    """
    Retrieves RPCd address from the database
    """

    find_active_node_sql_tmpl = """SELECT node_name FROM ft_node_status
                                  WHERE app_name='%s'
                                  AND cluster_name='%s'
                                  AND node_state='active' LIMIT 1"""

    find_rpc_service_sql_tmpl = """SELECT service_hostname, service_port
                                  FROM ft_node_services
                                  WHERE app_name='%s'
                                  AND cluster_name='%s'
                                  AND service_name='%s'
                                  AND node_name ='%s' LIMIT 1"""

    find_active_node_sql = find_active_node_sql_tmpl % (app_name, cluster_name)

    cursor = conn.cursor()
    try:
        cursor.execute(find_active_node_sql)
        active_node_name = cursor.fetchall()
        if active_node_name:
            active_node_name = active_node_name[0][0]
            find_rpc_service_sql = find_rpc_service_sql_tmpl % \
                    (app_name, cluster_name, rpc_service_name, active_node_name)
            cursor.execute(find_rpc_service_sql)
            rows = cursor.fetchall()
            if rows:
                return rows[0][0], int(rows[0][1])
    finally:
        cursor.close()

def rpc_ping(address, method_name, args, timeout, \
                                expected_resp=None, verbosity=0):
    """
    Performs RPC ping to specified RPC server

    :param address:             server address tuple
    :param method_name:         remote method name
    :param args:                remote method args
    :param expected_resp:       expected response
    :param verbosity:           verbosity level
    """
    result = nagios_plugins.RESULT_CRITICAL
    msg = ''
    try:
        client = simple_fastrpc_client(address, connect_timeout=timeout)
        try:
            data = client.request((method_name,), args)
            if expected_resp is None or str(data) == expected_resp:
                result = nagios_plugins.RESULT_OK
                msg = 'Received OK status from server'
            else:
                result = nagios_plugins.RESULT_WARNING
                msg = 'Wrong response received from server'
                if verbosity > 0:
                    msg += '. Expected response: %s, received response: %s' % \
                                                        (expected_resp, data)
        finally:
            client.close()
    except (ServerUnreachable, ConnectionError), exc:
        result = nagios_plugins.RESULT_CRITICAL
        msg = 'Connection failed. Reason: %s' % (exc,)
    except RPCError, exc:
        result = nagios_plugins.RESULT_CRITICAL
        msg = 'RPC method call failed.'
        if verbosity > 1:
            # RPCError contains server traceback string which
            # we don't want to display unless verbosity < 2
            msg += '\n%s' % (exc,)
    except socket.timeout:
        result = nagios_plugins.RESULT_CRITICAL
        msg = 'Connection failed. Reason: timeout'
    except:
        result = nagios_plugins.RESULT_CRITICAL
        msg = 'Unknown error'

    return result, msg


def check_ft_service(opt):
    """
    Performs FT service status check
    """
    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = ''

    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)
    try:
        # check ftdb schema first
        result, msg = check_db_schema(conn)
        if result != nagios_plugins.RESULT_OK:
            return result, msg

        # find the RPCd address
        rpcd_addr = get_rpcd_addr(conn, opt.app_name, \
                                        opt.cluster_name, opt.service_name)
        if rpcd_addr is None:
            result = nagios_plugins.RESULT_CRITICAL
            msg = 'Cannot find RPC service %s running for cluster %s of %s' % \
                            (opt.service_name, opt.app_name, opt.cluster_name)
            return result, msg

        # ping the RPCd service
        args = ()
        if opt.method_args:
            args = map(eval, opt.method_args.split())

        result, msg = rpc_ping(rpcd_addr, opt.rpc_method, args, opt.timeout, \
                                opt.expected_resp, opt.verbosity)
        return result, msg
    finally:
        conn.close()


def main():
    optp = make_option_parser()
    try:
        opt, _ = process_args(optp)
    except nagios_plugins.UsageError, exc:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(exc))

    try:
        result, msg = check_ft_service(opt)
    except Exception, exc:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s: " % (exc,)

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
