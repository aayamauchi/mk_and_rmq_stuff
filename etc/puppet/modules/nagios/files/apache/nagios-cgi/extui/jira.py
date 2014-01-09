jiraurl = 'https://jira.sco.cisco.com/'
jirauser = 'nagios'
jirapass = 'thaxu1T'

import os
from pprint import pformat
from suds.client import Client
from suds.sax.date import DateTime as sudsdatetime
from cgi import escape

import logging
logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger('suds.client')
logger.setLevel(logging.ERROR)
ch = logging.StreamHandler()
formatter = logging.Formatter('<!-- %(name)s - %(levelname)s - %(message)s -->')
ch.setFormatter(formatter)
logger.addHandler(ch)

soap = None
auth = None

output = []
debug = {}


def linkIssue(key):
    '''return properly formmatted issue link'''
    return '%s/browse/%s' % (jiraurl, key)

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

class JiraCat(JiraCommand):

    name = "cat"
    summary = "Show all the fields in an issue"
    usage = """
    <issue key>           Issue identifier, e.g. CA-1234
    """

    def run(self, jira_env, args):
        global soap, auth
        if len(args) != 1:
            return 0
        issueKey = args[0]
        try:
            jira_env['fieldnames'] = soap.service.getFieldsForEdit(auth, issueKey)
        except Exception, e:
            # In case we don't have edit permission
            jira_env['fieldnames'] = {}
        try:
            return soap.service.getIssue(auth, issueKey)
        except Exception, e:
            raise

    def render(self, jira_env, args, results):
        # For available field names, see the variables in
        # src/java/com/atlassian/jira/rpc/soap/beans/RemoteIssue.java
        fields = jira_env['fieldnames']
        for f in results['customFieldValues']:
            fieldName = str(f['customfieldId'])
        return 0


class JiraComments(JiraCommand):

    name = "comments"
    summary = "Show all the comments about an issue"
    usage = """
    <issue key>           Issue identifier, e.g. CA-1234
    """

    def run(self, jira_env, args):
        global soap, auth
        if len(args) != 1:
            return 0
        issueKey = args[0]
        try:
            return soap.service.getComments(auth, issueKey)
        except Exception, e:
            raise

    def render(self, jira_env, args, results):
        return 0

class JiraGetIssues(JiraCommand):

    name = "getissues"
    summary = "List Issues"
    usage = """
    "<search text>"             "Summary ~ '%some%text%' AND Reporter=nagios AND Created > -7d"
    [<limit>]                   Optional limit.  10 if not passed.
    """

    def run(self, jira_env, args):
        global soap, auth
        if len(args) == 2:
            limit = int(args[1])
            args = args[0]
        elif len(args) == 1:
            limit = 10
            args = args[0]
        else:
            return 0
        issues = soap.service.getIssuesFromJqlSearch(auth, args, limit)
        return issues

    def render(self, jira_env, args, results):
        global output
        def compare(a, b):
            if a == None:
                return b
            if b == None:
                return a
            return cmp(a['created'], b['created'])
        odde = {True: 'Odd', False: 'Even'}
        width = {'key': '12%', 'created': '8%', 'updated': '8%', 'assignee': '6%',
                'resolution': '6%', 'summary': '52%'}
        output.append('<th class=status width=12%>Issue</th><th class=status width=8%>Created</th>')
        output.append('<th class=status width=8%>Updated</th><th class=status width=6%>Assignee</th>')
        # https://jira.ironport.com/secure/QuickSearch.jspa?searchString=Summary~%22ip_ipmi%22
        output.append('<th class=status width=6%>Resolution</th>')
        output.append('<th class=status width=52%%>[%s]</th>' % (args[0]))
        odd = True
        for issue in results:
            output.append('<tr>')
            output.append('<td class=status%s>%s</td>' % \
                    (odde[odd], linkify(linkIssue(issue['key']), issue['key'])))
            for key in ['created', 'updated', 'assignee', 'resolution', 'summary']:
                if key in ['created', 'updated']:
                    output.append('<td class=status%s>%s</td>' % (odde[odd], escape(dateStr(issue[key]))))
                else:
                    output.append('<td class=status%s>%s</td>' % (odde[odd], escape(str(issue[key]))))
            output.append('</tr>')
            odd = not odd
        output.append('<!--')
        output.append('detailed data on last listed issue:')
        output.append(pformat(issue))
        output.append(pformat(dir(issue)))
        output.append('-->')
        return 0

class Commands:

    def __init__(self):
        self.commands = {}
        self.add(JiraCat)
        self.add(JiraComments)
        self.add(JiraGetIssues)

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

def encode(s):
    '''Deal with unicode in text fields'''
    if s == None:
        return "None"
    if type(s) == unicode:
        s = s.encode("utf-8")
    return str(s)

def dateStr(i):
    '''TODO Why are dates from JIRA at GMT-1?
    TODO Convert to 12 hour too?'''
    if i == None or i == 'None':
        return str(i)
    return i.isoformat(' ')

def decode(e):
    """Process an exception for useful feedback"""
    # TODO how to log the fact it is an error, but allow info to be unchanged?
    # The faultType class has faultcode, faultstring and detail
    str = e.faultstring
    if str == 'java.lang.NullPointerException':
        return "Invalid issue key?"
    return e.faultstring

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
            jira_env['subtypes'] = soap.service.getSubTaskIssueTypes(auth)
            jira_env['statuses'] = soap.service.getStatuses(auth)
            jira_env['priorities'] = soap.service.getPriorities(auth)
            jira_env['resolutions'] = soap.service.getResolutions(auth)
            if hasattr(soap, 'getProjects'):
                # Up to 3.12
                jira_env['projects'] = soap.service.getProjects(auth)
            else:
                jira_env['projects'] = soap.service.getProjectsNoSchemes(auth)
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

def getName(id, fields):
    '''TODO cache this, and note getCustomFields() needs admin privilege'''
    if id == None:
        return "None"
    if fields == None:
        return id
    for i, v in enumerate(fields):
        val = v['id']
        if val and val.lower() == id.lower():
            return v['name']
    return id.title()

def main(host, service=None):
    '''Return some JIRA data based on Nagios host/service'''
    global soap
    global auth
    global output
    com = Commands()
    jira_env = {}
    server = jiraurl + '/rpc/soap/jirasoapservice-v2?wsdl'
    try:
        soap = Client(server)
    except:
        print '<!-- Error connecting to JIRA -->'
        raise
    serverInfo = soap.service.getServerInfo(auth)
    output.append('<!--')
    start_login(jira_env, soap)
    output.append('-->')
    output.append('<hr>')
    output.append('<table border=0 cellspacing=2 cellpadding=2 width=98%>')
    if com.run('getissues', jira_env, 
            ['Summary ~ \'%%%s%%\' ORDER BY updated' % (host), 2]):
        output.append('<tr><td class=statusBGUNKNOWN>')
        output.append('No tickets found for "Summary ~ \'%%%s%%\' ORDER BY updated"' % (host))
        output.append('</td></tr>')
    output.append('</table>')
    if service is not None:
        service = service.replace(':', '%').replace('*', '%').replace(' ', '%')
        output.append('<table border=0 cellspacing=2 cellpadding=2 width=98%>')
        if com.run('getissues', jira_env, 
                ['Summary ~ \'%%%s/%s%%\' ORDER BY updated' % (host, service), 4]):
            output.append('<tr><td class=statusBGUNKNOWN>')
            output.append('No tickets found for "Summary ~ \'%%%s/%s%%\' ORDER BY updated"<br>' % (host, service))
            output.append('</td></tr>')
        output.append('</table>')

    return (output, jira_env)



