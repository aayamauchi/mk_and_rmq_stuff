#!/usr/bin/python26

# -*- coding: ascii -*-

# Sends a test message through CRES to a dummy account
# Mike Lindsey (mlindsey@ironport.com) 12/20/2007


import base64
import os
import socket
import sys
import traceback
import time
import re
import urllib2
from urlparse import urlparse
import ClientCookie
import mailbox
import email

from optparse import OptionParser

def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    parser = OptionParser()
    # -H res.cisco.com -u 'systemops@ironport.com' -p 'flyingm0nkeys' -t 'cres-nagios-lists@lists.ironport.com'
    parser.add_option("-H", "--host", type="string", dest="host",
                            default="res.cisco.com",
                            help="host or vip to connect to")
    parser.add_option("-u", "--username", type="string", dest="username",
                            default="systemops@ironport.com",
                            help="Username to log into CRES with.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            default="flyingm0nkeys",
                            help="CRES account password")
    parser.add_option("-t", "--to", type="string", dest="to",
                            default="stbu-nagios-cres@external.cisco.com",
                            help="Email address to send mail to.")
    parser.add_option("-m", "--mailbox", type="string", dest="mailbox",
                            help="Mailbox for receipt verification.",
                            default='/var/spool/mail/cres')
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    exitflag = 0
    if exitflag > 0:
        parser.print_help()
        sys.exit(0)
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

    return options

def connect_and_compose():
    """Connect to CRES and send a test message"""
    start = time.time()
    url = 'https://%s/websafe/./validateLocalLogin.action' % (options.host)

    try:
        client = ClientCookie.urlopen(url,'id=%s&password=%s' % \
        (options.username, options.password))
    except urllib2.HTTPError, e:
        print "CRITICAL - HTTPError: %d" % (e.code or 'unknown')
        sys.exit(2)
    if options.verbose:
        print "Connected to %s" % (url)
                
    state = ''
    for line in client.readlines():
        if re.compile('Compose Message').search(line):
            state = 'ok'
            break

    if state != 'ok':
        print "Error during login process."
        sys.exit(2)

    state = ''

    url = 'https://%s/websafe/./custom.action?cmd=sendMsg&sendmail=true' % (options.host)
    try:
        client = ClientCookie.urlopen(url,'to=%s&subject=Automated Test&message=Whee' % \
                (options.to))
    except urllib2.HTTPError, e:
        print "CRITICAL - HTTPError: %d" % (e.code or 'unknown')
        sys.exit(2)
                
    for line in client.readlines():
        if re.compile('Your email has been sent').search(line):
            state = 'ok'
            if options.verbose:
                print "Your email has been sent to %s" % (options.to)
            break

    if state != 'ok':
        print "Error attempting to send email."
        sys.exit(2)
    return time.time() - start

def check_mailbox_age():
    """Hit the mail spool and make sure it's not too old."""
    try:
        age = time.time() - os.path.getmtime(options.mailbox)
    except:
        print "Systemic issue retrieving email."
        sys.exit(3)

    if age > 1200:
        print "Last mail recieved more than 1200 seconds ago (%s)" % (age)
        sys.exit(2)
    elif age > 600:
        print "Last mail recieved more than 600 seconds ago (%s)" % (age)
        sys.exit(1)
    return age

def extract_result_url():
    """Read the last message from the mbox that's from CRES
    extract the attachment, read and return the resulting url"""
    # Uhh, there's a bigass nasty chunk of javascript involing ARC4 decryption
    # and god knows what else incomprehensible code-compressed gibberish to
    # parse out here.  Hitting the brakes while I wait for cres devs to give
    # a flashlight to fight the darkness.

    ok = False
    mbox = open(options.mailbox)
    messages = mailbox.UnixMailbox(mbox, email.message_from_file)
    while True:
        message = messages.next()
        if message is None:
            break
        for data in message.walk():
            if str(data.get_filename()).startswith('securedoc'):
                last = data
                ok = True
    
    if not ok:
        print "Error retrieving securedoc.html payload from message."
        sys.exit(2)
    return last

if __name__ == '__main__':
    options = init()
    duration = connect_and_compose()
    age = check_mailbox_age()
    extract_result_url()
    print "CRES functioning properly, connect and compose in %2.2fs, last message %2.2fs ago." % (duration, age)
    sys.exit(0)

