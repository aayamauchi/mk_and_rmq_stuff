#!/usr/bin/env python26

import email
import os
import sys
import cgi

#from cgi import escape

from quopri import decodestring
from pprint import pformat
from shutil import move

jiraurl = 'https://jira.ironport.com/'
maildir = '/usr/local/ironport/nagios/mail/Sysops_Alert/'
# https://jira.ironport.com/secure/QuickSearch.jspa?searchString=Summary~'prod-vectorwbnp-db-m1.vega.ironport.com/vectorwbnp_replayable_urls_last_insert'
jirauser = 'nagios'
jirapass = 'thaxu1T'

from suds.client import Client
from suds.sax.date import DateTime as sudsdatetime

soap = None
auth = None

output = []
debug = {}


def linkJira(subject):
    '''Get an email string, return a link to hopefully matching tickets.'''
    global soap
    global auth
    com = Commands()
    jira_env = {}
    server = jiraurl + '/rpc/soap/jirasoapservice-v2?wsdl'
    try:
        soap = Client(server)
    except:
        print '<!-- Error connecting to JIRA -->'
        raise
    serverInfo = soap.service.getServerInfo(auth)
    start_login(jira_env, soap)
    key = com.run('getissue', jira_env, 
            'Summary ~ \'%s\' ORDER BY updated' % (subject.replace(' ', '%')))
    if key == 1:
        return subject
    else:
        return linkify(linkIssue(key), subject)

def linkIssue(key):
    '''return properly formmatted issue link'''
    return '%sbrowse/%s' % (jiraurl, key)

def linkify(link, text=None):
    '''Take a string, return a link, if it is recognizeable as a url'''
    if text is None:
        text = link
    if '://' in link:
        link = '<a href=\'%s\'>%s</a>' % (link, text)
    return link

class JiraCommand:
    name = "<default>"
    aliases = []
    summary = "<--- no summary --->"
    usage = ""
    mandatory = ""

    commands = None

    def __init__(self, commands):
        self.commands = commands

    def dispatch(self, jira_env, args):
        """Return the exit code of the whole process"""
        results = self.run(jira_env, args)
        if results:
            return self.render(jira_env, args, results)
        else:
            return 1

    def run(self, jira_env, args):
        """Return a non-zero object for success"""
        return 0

    def render(self, jira_env, args, results):
        """Return 0 for success"""
        return 0

def encode(s):
    '''Deal with unicode in text fields'''
    if s == None:
        return "None"
    if type(s) == unicode:
        s = s.encode("utf-8")
    return str(s)

class JiraGetIssue(JiraCommand):

    name = "getissue"
    summary = "List Issue"

    def run(self, jira_env, args):
        results = soap.service.getIssuesFromJqlSearch(auth, args, 1)
        if len(results):
            return results[0]
        else:
            return 0

    def render(self, jira_env, args, results):
        if results:
            return encode(results['key'])
        else:
            return None

class Commands:

    def __init__(self):
        self.commands = {}
        self.add(JiraGetIssue)

    def add(self, cl):
        # TODO check for duplicates in commands
        c = cl(self)
        self.commands[c.name] = c
        for a in c.aliases:
            self.commands[a] = c

    def has(self, command):
        return self.commands.has_key(command)

    def run(self, command, jira_env, args):
        """Return the exit code of the whole process"""
        return self.commands[command].dispatch(jira_env, args)

    def getall(self):
        keys = self.commands.keys()
        keys.sort()
        return map(self.commands.get, keys)

def start_login(jira_env, soap):
    global auth
    jirarc = '/tmp/.nagios_extended_ui.auth'
    authorized = False
    while not authorized:
        fp = None
        if not os.path.exists(jirarc):
            auth = soap.service.login(jirauser, jirapass)
        else:
            fp = open(jirarc, 'rb')
            auth = fp.read()
            fp.close()
        try:
            jira_env['types'] = soap.service.getIssueTypes(auth)
            #jira_env['subtypes'] = soap.service.getSubTaskIssueTypes(auth)
            #jira_env['statuses'] = soap.service.getStatuses(auth)
            #jira_env['priorities'] = soap.service.getPriorities(auth)
            #jira_env['resolutions'] = soap.service.getResolutions(auth)
            #if hasattr(soap, 'getProjects'):
                # Up to 3.12
                #jira_env['projects'] = soap.service.getProjects(auth)
            #else:
                #jira_env['projects'] = soap.service.getProjectsNoSchemes(auth)
            authorized = True
            if fp is None:
                # logged in this time, write cache
                fp = open(jirarc, 'wb')
                fp.write(auth)
                fp.close()
        except Exception, e:
            if os.path.exists(jirarc):
                os.remove(jirarc)
            else:
                raise

def main(host, service, args=''):
    output = []

    # prevent repeated argument submission.
    selfurl = '%s' % (os.environ['REQUEST_URI'])
    if '&args' in selfurl:
        import re
        selfurl = re.sub('&args=[a-zA-Z0-9:._\-]*', '', selfurl)

    # argument handling here.
    if args:
        if args.startswith('clear:'):
            file = args.split(':',1)[1].replace('..','').strip('/\\${}[]') # strip dangerous characters
                                                                           # just in case someone tries to
                                                                           # get 'fresh'
            if os.path.exists(maildir + 'new/' + file):
                # move to cur.
                move(maildir + 'new/' + file, maildir + 'cur/')
            else:
                # just ignoring anything that looks like invalid data.
                pass
        elif args.startswith('unclear:'):
            file = args.split(':',1)[1].replace('..','').strip('/\\${}[]') # strip dangerous characters
                                                                           # just in case someone tries to
                                                                           # get 'fresh'
            if os.path.exists(maildir + 'cur/' + file):
                # move to cur.
                move(maildir + 'cur/' + file, maildir + 'new/')
            else:
                # just ignoring anything that looks like invalid data.
                pass

    if os.listdir(maildir + 'new/'):
        # begin table output.
        output.append('<table width=98%% border=0 cellspacing=2 cellpadding=0>')
        output.append('<tr><th class=status width=20%%>From</th><th class=status width=15%%>Date</th>')
        output.append('<th class=status>Subject + Body</th><th class=status width=8%%>Action</th></tr>')
        output.append('<font size +2>')
        for file in os.listdir(maildir + 'new/')[::-1]: # newest first.
            ffile = maildir + 'new/' + file
            fd = open(ffile)
            msg = email.message_from_file(fd)
            fd.close()
            output.append('<tr><td class=statusBGCRITICAL valign=top>')
            if msg.has_key('From'):
                output.append('%s' % (msg['From']))
            else:
                output.append('Mail file corrupt')
            output.append('</td><td class=statusBGCRITICAL valign=top>')
            if msg.has_key('Date'):
                output.append('%s' % (msg['Date']))
            else:
                output.append('Mail file corrupt')
            output.append('</td><td class=statusBGCRITICAL valign=top>')
            if msg.has_key('Subject'):
                sub = False
                if msg.get_content_maintype() == 'multipart':
                    for part in msg.walk():
                        if part.get_content_maintype() == 'text':
                            output.append('%s\n<pre>%s<pre>' % \
                                    (linkJira(msg['Subject']), decodestring(part.get_payload().rstrip(' \n'))))
                            sub = True
                            break
                elif msg.get_content_maintype() == 'text':
                    output.append('%s\n<pre>%s<pre>' % (linkJira(msg['Subject']), msg.get_payload().rstrip(' \n')))
                    sub = True
                if sub == False:
                    output.append('%s\n<pre>No body found for:\n\'%s\'</pre>' % (linkJira(msg['Subject']), file))
                    
            else:
                output.append('Mail file corrupt')
            output.append('<td class=statusBGCRITICAL valign=top>')
            output.append('<a href="%s&args=clear:%s">Clear This</a>' % (selfurl, file))
            output.append('</td></tr>')
        output.append('</table>')
        output.append('</font>')
    else:
        output.append('<b>No current Manual Pages</b><img src="/nagios/images/greendot.gif"><br>')


    output.append('<b>History</b><br>')
    output.append('<table width=98%% border=0 cellspacing=2 cellpadding=0>')
    output.append('<tr><th class=status width=20%%>From</th><th class=status width=15%%>Date</td>')
    output.append('<th class=status>Subject</th><th class=status width=8%%>Action</th></tr>')

    for file in os.listdir(maildir + 'cur/')[:-3:-1]:
        ffile = maildir + 'cur/' + file
        fd = open(ffile)
        msg = email.message_from_file(fd)
        fd.close()
        output.append('<tr><td class=statusBGUNKNOWN valign=top>')
        if msg.has_key('From'):
            output.append('%s' % (msg['From']))
        else:
            output.append('Mail file corrupt')
        output.append('</td><td class=statusBGUNKNOWN valign=top>')
        if msg.has_key('Date'):
            output.append('%s' % (msg['Date']))
        else:
            output.append('Mail file corrupt')
        output.append('</td><td class=statusBGUNKNOWN valign=top>')
        if msg.has_key('Subject'):
            output.append('%s' % (linkJira(msg['Subject'])))
        else:
            output.append('Mail file corrupt')
        output.append('<td class=statusBGUNKNOWN valign=top>')
        output.append('<a href="%s&args=unclear:%s">Unclear This</a>' % (selfurl, file))
        output.append('</td></tr>')
    output.append('</table>')

    return (output, {'nocacti': 1, 'nojira': 1, 'nobanner': 1})


