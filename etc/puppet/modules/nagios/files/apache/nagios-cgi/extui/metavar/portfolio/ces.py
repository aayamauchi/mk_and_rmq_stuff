"""Script for pulling logs and stats data out of an IronPort hostname
via ssh.  Output is suitable for Nagios extended UI

Mike Lindsey <miklinds@cisco.com>  9/15/2011
"""
 
# -*- coding: ascii -*-
import time
import warnings
warnings.filterwarnings('ignore')
import sys
import os
from pprint import pformat

error_str = ''

def main(host, service, args, host_s, service_s):
    if host_s.has_key('_PURPOSE'):
        if ('esa' in host_s['_PURPOSE'] or 'sma' in host_s['_PURPOSE']):
            return ('', {'nojira': 1})
    return ('', {})
