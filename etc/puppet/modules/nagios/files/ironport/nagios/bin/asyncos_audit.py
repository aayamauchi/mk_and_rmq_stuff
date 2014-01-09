#!/usr/bin/env python26
"""Script for pulling logs and stats data out of an IronPort hostname
via ssh.  Output is suitable for host-audit.sh

Mike Lindsey <miklinds@cisco.com>  9/15/2011
"""
 
# -*- coding: ascii -*-
import time
import warnings
warnings.filterwarnings('ignore')
import paramiko
import fcntl # have had a hell of a time getting paramiko to work right with a pty.
             # Switching to file-like access instead.
import sys
import os
import stat
import socket
import re
from pprint import pformat

error_str = ''
audit_dir = '/usr/local/nagios/www/nagios/audit'

def connect(hostname, username, password):
    """Connect and return a SSHClient object"""
    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy()) 
    global error_str
    error = 0
    try:
        client.connect(hostname=hostname, username=username, \
                password=password, port=22, timeout=5)
    except paramiko.BadAuthenticationType:
        error_str += "BadAuthenticationType Failure for %s\n" % (hostname)
        error = 1
    except paramiko.AuthenticationException:
        error_str += "Authentication Failure '%s' for %s@%s\n" % (sys.exc_info()[1], username, hostname)

        error = 1
    except socket.gaierror:
        error_str += "'%s' error for %s\n" % (sys.exc_info()[1][1], hostname)
        error = 1
    except socket.error:
        error_str += "Socket error for %s\n" % (hostname)
        error = 1
    except:
        error_str += "Connection Error for %s\n" % (hostname)
        error_str += "%s\n" % (str(sys.exc_info()))
        error = 1

    if error:
        return (None, None, None)


    transport = client.get_transport()
    try:
        channel = client.invoke_shell(term='vt100', width=120, height=500)
    except paramiko.SSHException:
        channel = None
    else:
        channel.setblocking(0)

    return (client, channel, transport)

def get_data(hostname, username, password):
    """Hit a hostname and grab all the stats"""
    (client, channel, transport) = connect(hostname, username, password)
    if (client, channel, transport) == (None, None, None):
        return ([error_str,], {})

    if channel is not None:
        status = ['<!--']
        out = ''
        x = 0
        while not channel.send_ready():
            x += 1
            time.sleep(0.01)
            if x > 100:
                status.append('Timed out querying device.')
        status.append('query delay: %0.2fs' % (x * 0.01))

        x = 0
        while not channel.recv_ready():
            time.sleep(0.01)
            x += 1
        status.append('recv_ delay: %0.2fs' % (x * 0.01))

        x = 0
        while x < 100:
            # purge the banner
            try:
                z = channel.recv(1024)
            except:
                time.sleep(0.01)
                x += 1
            else:
                if '>' in z:
                    break

        status.append('banner purge delay: %0.2fs' % (x * 0.01))

        #commands = ['status detail', 'tail antispam', 'tail antivirus', 'tail error_logs', 'tail mail_logs']
        commands = ['status detail',]
        tabs = []
        output = {}
        for cmd in commands:
            x = 0
            #out += '\n<b>%s</b>\n' % (cmd)
            while not channel.send_ready():
                x += 1
                if x > 100:
                    status.append('channel.send_ready() == False')
                    break
                time.sleep(0.01)
            status.append('cmd: %s, send delay %0.2fs' % (cmd, x * 0.01))
            if channel.send_ready():
                channel.send(cmd)
            #while channel.recv_ready():
                ## Purge prompt
                #x = channel.recv(1024)

            channel.send('\n')

            x = 0
            while not channel.recv_ready():
                x += 1
                if x > 200:
                    status.append('channel.recv_ready() == False')
                    break
                time.sleep(0.01)
            status.append('cmd: %s, recv_ready delay %0.2fs' % (cmd, x * 0.01))
            x = 0
            out = ''
            while x < 100:
                while channel.recv_ready():
                    _out = channel.recv(1024)
                    if _out == cmd:
                        _out = ''
                        continue
                    out += _out
                    if _out[-2:-1] == '> ':
                        # got prompt, continue
                        x = 100
                        break

                    time.sleep(0.01)

                x += 1
                time.sleep(0.02)
            if 'Ctrl-C to stop' in _out:
                channel.send('\x03')

            out = out.replace('"', '\'').replace('^C', '').replace('Press Ctrl-C to stop.', '')\
                    .lstrip('\n').rstrip('\n')
            out += '\n'.join(status)
            out += '-->'

        return out
    else:
        return error_str


def run(client, cmd):
    """Open channel on transport, run command, capture output and return"""
    stdin, stdout, stderr = client.exec_command("%s" % (cmd))
    out = stdout.read()
    return out


if __name__ == '__main__':
    host = sys.argv[1]
    user = sys.argv[2]
    word = sys.argv[3]

    try:
        paramiko.util.log_to_file('/dev/null')
    except:
        pass 
    out = get_data(host, user, word)
    print out

