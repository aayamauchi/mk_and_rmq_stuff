"""Script for pulling logs and stats data out of an IronPort hostname
via ssh.  Output is suitable for Nagios extended UI

Mike Lindsey <miklinds@cisco.com>
"""
 
# -*- coding: ascii -*-
import time
import warnings
warnings.filterwarnings('ignore')
import sys
import os
from pprint import pformat

error_str = ''
audit_dir = '/usr/local/nagios/www/nagios/audit'

def main(host, service, args, host_s, service_s):
    file = audit_dir + '/' + host + '.html'
    if os.path.exists(file):
        audit = {'tabs': [{'header': 'Status Detail',
                'body': '<iframe src=/nagios/audit/%s width=98%% height=1000><p>No iframe support</p></iframe>' %
                            (host + '.html')}]}
    else:
        audit = {}

    return ([], audit)
