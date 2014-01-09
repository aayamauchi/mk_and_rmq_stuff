#!/usr/bin/env python26
'''Extra Action/Notes CGI for Nagios.  Depends on NagiosStatd for data presentation.
Limited functionality available if stats daemon down.
Pull in Cacti Graphs, Provide Ticket search links, and Service history.'''


import cgi
import cgitb; cgitb.enable()
form = cgi.FieldStorage()

from exceptions import TypeError

import os
import sys
sys.stderr = sys.stdout # redirect stderr to stdout for easier in-ui error reporting

from pprint import pprint
import socket
import simplejson
import time
import datetime

from urllib2 import unquote, quote

qsafe = ''' `~!@#$%^&*()-=_+;':",.<>/?[]\\{}|\n''' # + \\ \'

import MySQLdb
import socket

sys.path.insert(0, os.path.dirname(__file__))

start = time.time()

try:
    statsserver = open(os.path.dirname(__file__) + '/statsserver.txt').read().strip()
except:
    statsserver = 'ops-mon-nagios1.vega.ironport.com'

statsport = 8667

states = {'host': {  0: 'UP',
                     1: 'DOWN',
                     2: 'UNREACHABLE',
                     'UP': 0,
                     'DOWN': 1,
                     'UNREACHABLE': 2},
        'service': { 0: 'OK',
                     1: 'WARNING',
                     2: 'CRITICAL',
                     3: 'UNKNOWN',
                    'OK': 0,
                    'WARNING': 1,
                    'CRITICAL': 2,
                    'UNKNOWN': 3},
        'ack': {    0: 'NO',
                    1: 'YES',
                    2: 'YES',
                    'NO': 0,
                    'YES': 1,
                    'YES': 2},
        'type': {   0: 'SOFT',
                    1: 'HARD',
                    'SOFT': 0,
                    'HARD': 1},
        'enabled': {0: 'DISABLED',
                    1: 'ENABLED',
                    'DISABLED': 0,
                    'ENABLED': 1},
        'flap':    {0: 'Not Flapping',
                    1: 'FLAPPING'}}

# Command globals
arg_types = {'host_name': 'string', 'sticky': '0-2', 'notify': '0-1',
        'persistent': '0-1', 'author': 'string', 'comment_data': 'string',
        'service_description': 'string', 'comment_id': 'int',
        'downtime_id': 'int', 'status_code': '0-2', 'plugin_output': 'string',
        'return_code': '0-2', 'start_time': 'time_t', 'end_time': 'time_t',
        'fixed': '0-1', 'trigger_id': 'int', 'duration': 'int', 'check_time': 'time_t',
        'hostgroup_name': 'string', 'servicegroup_name': 'string', 'options': '0-7'}

arg_default = {'host_name': form.getvalue('host'), 'sticky': 1, 'notify': 0,
        'persistent': 0, 'author': os.environ['REMOTE_USER'], 'comment_data': '_',
        'service_description': form.getvalue('service', None), 'comment_id': None,
        'downtime_id': None, 'status_code': 0, 'plugin_output': None,
        'return_code': 0, 'start_time': int(time.time()), 'end_time': int(time.time() + 3600),
        'fixed': 1, 'trigger_id': 0, 'duration': 3600, 'check_time': int(time.time()),
        'hostgroup_name': None, 'servicegroup_name': None, 'options': 0}

commands = {'ACKNOWLEDGE_HOST_PROBLEM': {'args': ['host_name', 'sticky', 'notify', 'persistent',
                'author', 'comment_data']},
        'ACKNOWLEDGE_SVC_PROBLEM': {'args': ['host_name', 'service_description', 'sticky', 'notify',
                'persistent', 'author', 'comment_data']},
        'ADD_HOST_COMMENT': {'args': ['host_name', 'persistent', 'author', 'comment_data']},
        'ADD_SVC_COMMENT': {'args': ['host_name', 'service_description', 'persistent', 'author',
                'comment_data']},
        'DEL_HOST_COMMENT': {'args': ['comment_id',]},
        'DEL_HOST_DOWNTIME': {'args': ['downtime_id',]},
        'DEL_SVC_COMMENT': {'args': ['comment_id',]},
        'DEL_SVC_DOWNTIME': {'args': ['downtime_id',]},
        'PROCESS_HOST_CHECK_RESULT': {'args': ['host_name', 'status_code', 'plugin_output']},
        'PROCESS_SERVICE_CHECK_RESULT': {'args': ['host_name', 'service_description', 'return_code',
                'plugin_output']},
        'REMOVE_HOST_ACKNOWLEDGEMENT': {'args': ['host_name',]},
        'REMOVE_SVC_ACKNOWLEDGEMENT': {'args': ['host_name', 'service_description']},
        'SCHEDULE_AND_PROPAGATE_HOST_DOWNTIME': {'args': ['host_name', 'start_time', 'end_time',
                'fixed', 'trigger_id', 'duration', 'author', 'comment_data']},
        'SCHEDULE_FORCED_HOST_CHECK': {'args': ['host_name', 'check_time']},
        'SCHEDULE_FORCED_HOST_SVC_CHECKS': {'args': ['host_name', 'check_time']},
        'SCHEDULE_FORCED_SVC_CHECK': {'args': ['host_name', 'service_description', 'check_time']},
        'SCHEDULE_HOSTGROUP_HOST_DOWNTIME': {'args': ['hostgroup_name', 'start_time', 'end_time', 'fixed',
                'trigger_id', 'duration', 'author', 'comment_data']},
        'SCHEDULE_HOSTGROUP_SVC_DOWNTIME': {'args': ['hostgroup_name', 'start_time', 'end_time', 'fixed',
                'trigger_id', 'duration', 'author', 'comment_data']},
        'SCHEDULE_HOST_DOWNTIME': {'args': ['host_name', 'start_time', 'end_time', 'fixed', 'trigger_id',
                'duration', 'author', 'comment_data']},
        'SCHEDULE_HOST_SVC_DOWNTIME': {'args': ['host_name', 'start_time', 'end_time', 'fixed',
                'trigger_id', 'duration', 'author', 'comment_data']},
        'SCHEDULE_SERVICEGROUP_HOST_DOWNTIME': {'args': ['servicegroup_name', 'start_time', 'end_time',
                'fixed', 'trigger_id', 'duration', 'author', 'comment_data']},
        'SCHEDULE_SERVICEGROUP_SVC_DOWNTIME': {'args': ['servicegroup_name', 'start_time', 'end_time',
                'fixed', 'trigger_id', 'duration', 'author', 'comment_data']},
        'SCHEDULE_SVC_DOWNTIME': {'args': ['host_name', 'service_description', 'start_time', 'end_time',
                'fixed', 'trigger_id', 'duration', 'author', 'comment_data']},
        'SEND_CUSTOM_HOST_NOTIFICATION': {'args': ['host_name', 'options', 'author', 'comment_data']},
        'SEND_CUSTOM_SVC_NOTIFICATION': {'args': ['host_name', 'service_description', 'options',
                'author', 'comment_data']}}

# sloppy globals.
cmdfile  = '/usr/local/nagios/var/rw/nagios.cmd'

self_url = '%s' % (os.environ['REQUEST_URI'])
if '&cmd=' in self_url: # sloppy, but acceptable with current code.
    self_url = self_url.split('&cmd=')[0]

conn = None
tname = 'device'

debug = False

def linkify(link, text=None):
    '''Take a string, return a link, if it is recognizeable as a url'''
    if text is None:
        text = link
    if '://' in link:
        link = '<a href=\'%s\'>%s</a>' % (link, text)
    return link

def init_cmd(cmdfile):
    '''Initialize Command Pipe, return None in case of failure.'''
    try:
        cmdfh = open(cmdfile, 'a')
    except:
        cmdfh = None
    return cmdfh

def send_cmd(cmdfh, cmd, args=[]):
    '''Send a command to the pipe.  Most arguments if missing, will default to sane values.
    Full command list at: http://old.nagios.org/developerinfo/externalcommands/commandlist.php'''

    if cmdfh is None:
        return (False, 'No Command pipe file handle.')
    elif cmd not in commands.keys():
        return (False, 'Command "%s" unknown.' % (cmd))

    _args = {}
    # form.getvalue() returns string, or list, so we have to test and munge.
    if str(type(args)) == "<type 'str'>":
        args = [args,]
    for arg in args:
        _args[arg.split(':')[0]] = arg.split(':', 1)[1].replace('<', '&lt;').replace('>', '&gt;')

    args = _args

    # munge missing arguments
    for arg in commands[cmd]['args']:
        # if not already in args, check for descrete variables.
        if arg not in args and form.getvalue(arg, None) is not None:
            args[arg] = form.getvalue(arg).replace('<', '&lt;').replace('>', '&gt;')
        # else, try grabbing a default
        elif arg not in args and arg_default[arg] is not None:
            args[arg] = arg_default[arg]

    if len(args) != len(commands[cmd]['args']):
        return (False, 'Command argument mismatch.  %i != %i<br>' % (len(args), len(commands[cmd]['args'])) + 
                '%s // %s' % (args, commands[cmd]['args']))
    else:
        try:
            for arg in args.keys():
                if arg_types[arg] == 'string':
                    args[arg] = str(args[arg])
                elif arg_types[arg] == 'int':
                    args[arg] = int(args[arg])
                elif arg_types[arg] == 'time_t':
                    # something's reverting the datetimestamp to int, previous to this.
                    _arg = args[arg].split()
                    try:
                        (y, m, d) = _arg[0].split('-')
                        (h, mi, s) = _arg[1].split(':')
                        t = (int(y), int(m), int(d), int(h), int(mi), int(s), -1, -1, -1)
                    except:
                        return (False, 'Invalid date/time format detected.<br>Downtime not submitted.')
                    
                    args[arg] = int(time.mktime(t))
                elif '-' in arg_types[arg]:
                    args[arg] = int(args[arg])
                    if args[arg] < int(arg_types[arg].split('-')[0]) or \
                            args[arg] > int(arg_types[arg].split('-')[1]):
                        raise TypeError
        except TypeError:
            raise
            return (False, 'Command arg validation failed.  %s is "%s" should be "%s"'
                    % (arg, args[arg], arg_types[arg]))

    arguments = []
    for arg in commands[cmd]['args']:
        arguments.append(str(args[arg]))

    try:
        print >> cmdfh, '[%i] %s;%s'  % (time.time(), cmd, ';'.join(arguments))
        if cmd == 'SCHEDULE_HOST_DOWNTIME':
            print >> cmdfh, '[%i] SCHEDULE_HOST_SVC_DOWNTIME;%s'  % (time.time(), ';'.join(arguments))
    except:
        print 'Unexpected Error submitting command: %s<br>' % (cmd)
        print '&nbsp;- %s' % (arguments)

        raise

    return (True, ';'.join(arguments))


def seconds_to_hms(seconds, ago=False):
    '''Takes a number of seconds and returns it as #h#m#s'''
    if ago:
        seconds = start - seconds
    seconds = int(seconds)
    days    = seconds / 86400
    hours   = (seconds % 86400) / 3600
    minutes = (seconds % 3600) / 60
    seconds = seconds % 60
    return "%sd %sh %sm" % (days, hours, minutes)

def get_nagiosstats(query, debug=False):
    '''Connect to the stats server, and run the query.  Return the results'''
    sock = socket.socket()
    output = ''
    if debug:
        print '<pre>'
    else:
        print '<!--'
    try:
        sock.connect((statsserver, statsport))
    except:
        print 'Error connecting to server %s:%s' % (statsserver, statsport)
    else:
        print '[%.2f] Connected to Server' % (time.time())
        if debug:
            print query
        sock.send('%s\n' % (query))
        try:
            package_size = int(sock.recv(24))
        except:
            print 'Error getting package size.'
        else:
            if debug:
                print '[%.2f] Receiving %i byte package' % (time.time(), package_size),
            if package_size > 1024:
                packet = 1024
            else:
                packet = package_size
            recieved = 0
            left = package_size
            while len(output) < package_size:
                output += sock.recv(packet)
                left = left - packet
                recieved += packet
            if len(output) != package_size:
                print 'Expected %s byte package, got %s bytes.' % (package_size, len(output))
            output = simplejson.loads(output)
            print "[%.2f] Deserialized payload" % (time.time())
            if 'query_ok' not in output:
                print 'Transfer failed, no \'query_ok\' key, keys: %s' % (output.keys())
            else:
                if output['query_ok'] is not True:
                    print '[%.2f] Transfer finished (Query Failed)' % (time.time())
                    pprint(output)
                else:
                    print '[%.2f] Transfer finished' % (time.time())
    if output == '':
        output = {}

    if not debug:
        print '-->'
    else:
        print '</pre>'
    return output

def flapping_state(object, status):
    '''Take status, return flapping state.'''
    if status['flap_detection_enabled']:
        output = '%s [State Change: %0.2f%% Options: %s Threshold: %i/%i]' % \
                (states['flap'][status['is_flapping']], status['percent_state_change'],
                object['flap_detection_options'],
                object['low_flap_threshold'], object['high_flap_threshold'])
                # 0/0 for threshold means it inherits from the global settings.
                # Update poll to grab that, in this case!
        output = output.replace(' Threshold: 0/0',  '') # for now, just clear it
    else:
        output = 'Flap Detection Disabled'
    return output

def do_sql(sql):
    cursor = conn.cursor()
    try:
        cursor.execute(sql)
    except:
        print '<!-- Error executing SQL \'%s\' -->' % (sql)
        results = []
    else:
        results = cursor.fetchall()
        conn.commit()
        if not len(results):
            results = None
        elif len(results) == 1:
            results = results[0][0]
        else:
            results = results
    return results

def embed_host(host, service, object, status, downtime, contact_can_see, contact_can_execute):
    '''take data, return output list and debug dict.
    Consider adjusting output based on contact_can_see, and whether or not service is None'''
    output = []
    output.append('<table border=1 cellspacing=0 cellpadding=0 width=98%>')
    output.append('<tr><td class=stateInfoTable1 bgcolor=f0f0f0>')

    now = time.time()
    in_downtime = False
    if host in downtime:
        #if type(downtime[host]) == type({}):
        #    # single returns come back as dict instead of array
        #    downtime = [downtime,]
        for d in downtime[host]:
            if d['start_time'] < now < d['end_time']:
                in_downtime     = True
                dt_author       = d['author']
                dt_comment      = d['comment']
                dt_end          = d['end_time']
                dt_id           = d['downtime_id']

    if not object.has_key('query_ok') or not object['query_ok']:
        output.append('<div class=serviceCRITICAL>Error retrieving Host Data</div>')
        output.append('&nbsp;Try <a href="/nagios/cgi-bin/extinfo.cgi?type=1&host=%s">Base UI</a>' % (host))
    else:
        output.append('<center><b>%s' % (host))
        if service is not None:
            output.append('/ %s' % (service))
        output.append('</b></center>')
        output.append('Host Data:<br>')
        output.append('<table border=0>')
	try:
	    type = states['type'][status['state_type']]
        except:
            return (['Check still Pending, return later.'], {'object': object, 'status': status})
        if type != 'HARD':
            type += ' (%i/%i)' % (status['current_attempt'], status['max_attempts'])
        output.append('<tr><td class=dataVar><b>State:</td>')
        output.append('<td class=dataVal>%s (%s) [Duration: %s]</td></tr>\n' % \
                (states['host'][status['current_state']], type, 
                seconds_to_hms(start - status['last_hard_state_change'])))
        if status['current_state'] > 0:
            # We're not OK.  Display it.
            output.append('<tr><td class=dataVar><b>Acknowledged:</b></td>')
            if type == 'HARD' and status['acknowledgement_type']:
                ackstr = '<a href="%s" title="Remove Host Acknowledgement">Yes</a>' % \
                        (self_url + '&cmd=REMOVE_HOST_ACKNOWLEDGEMENT')
                ackstr += '&nbsp; <img src="/nagios/images/ack.gif">'
            elif type == 'HARD':
                ackstr = '<a href="%s" title="Acknowledge Host Problem">NO</a>' % \
                        (self_url + '&cmd=ACKNOWLEDGE_HOST_PROBLEM')
            else:
                ackstr = states['ack'][status['acknowledgement_type']]
            output.append('<td class=dataVal>%s</td></tr>\n' % (ackstr))
        if in_downtime: # Add Future downtime?
            output.append('<tr><td class=dataVar valign=top><b>Downtime:</b></td>')
            if dt_comment == '_':
                output.append('<td class=dataVal valign=top>%s, ' % (dt_author))
            else:
                output.append('<td class=dataVal valign=top>%s, "%s" ' % (dt_author, dt_comment))
            output.append('&nbsp;&nbsp;- %s <a href="%s">' % 
                    (str(datetime.datetime.fromtimestamp(dt_end)).split('.')[0],
                     self_url + '&cmd=DEL_HOST_DOWNTIME&args=downtime_id:%i' % (dt_id)))
            output.append('<img src="/nagios/images/disabled.gif" title="Remove Downtime"></a></td></tr>\n')
            
        output.append('<tr><td class=dataVar><b>Flapping:</b></td>')
        output.append('<td class=dataVal>' + flapping_state(object, status) + '</td></tr>\n')
        output.append('<tr><td class=datavar valign=top><b>Output:</b></td>')
        output.append('<td class=dataVal><pre>%s' % (status['plugin_output']))
        output.append(status['long_plugin_output'].replace('\\n', '<br>') + '</pre></td></tr>\n')
        output.append('<tr><td>&nbsp;</td></tr>\n')

        # Sort and print custom variables.  
        keys = sorted(status.keys())
        for key in ['_PORTFOLIO', '_ENVIRONMENT', '_PRODUCT', '_PURPOSE', '_LOCATION',
                '_RACK', '_SERIAL', '_DEFAULT_ROUTE', '_HARDWARE', '_OS', '_SOURCE'][::-1]:
            if key in keys:  # Put these first, in alpha order.
                keys.insert(0, keys.pop(keys.index(key)))

        for key in keys:
            if key.startswith('__'):
                continue
            if key.startswith('_'):
                label = key[1:].replace('_', ' ')
                for word in label.split():
                    if len(word) > 2:
                        label = label.replace(word, '%s%s' % (word[0], word[1:].lower()))
                value = status[key].split(';',1)[1]
                value = linkify(value, value)  # Eh?
                output.append('<tr><td class=dataVar valign=top width=15%%><b>%s:<b></td>' % (label) +
                        '<td class=dataVal valign=top>%s</td></tr>\n' % (value))
        output.append('<tr><td class=dataVar valign=top><b>Hostgroups</b></td>')
        output.append('<td class=dataVal>')
        groups = []
        for group in sorted(object['groups']):
            groups.append('<a href="/nagios/cgi-bin/status.cgi?hostgroup=%s">%s</a>' %
                    (group, group))
        output.append(', '.join(groups))
        output.append('</td></tr>\n')

        output.append('</table>')


    output.append('</td></tr>\n</table>')

    return (output, {'object': object, 'status': status})

def embed_service(host, service, object, status, downtime, contact_can_see, contact_can_execute):
    '''take data, return output list and debug dict.
    Consider adjusting output based on contact_can_see (like displaying command line)'''
    output = []

    output.append('<table border=1 cellspacing=0 cellpadding=0 align=right width=98%>')
    output.append('<tr><td class=stateInfoTable1 bgcolor=f0f0f0>')

    now = time.time()
    in_downtime = False
    if 'query_ok' in downtime and downtime['query_ok']:
        for d in downtime[service]:
            if d['start_time'] < now < d['end_time']:
                in_downtime = True
                dt_author       = d['author']
                dt_comment      = d['comment']
                dt_end          = d['end_time']
                dt_id           = d['downtime_id']

    if not object.has_key('query_ok') or not object['query_ok']:
        output.append('<div class=serviceCRITICAL>Error retrieving Service Data</div>')
        output.append('&nbsp;Try <a href="/nagios/cgi-bin/extinfo.cgi?type=2&host=%s&service=%s">Base UI</a>' %
                (host, service))
    else:
        output.append('<center><b>%s</b></center>' % (service))
        output.append('Service Data:<br>')
        output.append('<table border=0>')
        type = states['type'][status['state_type']]
        if type != 'HARD':
            type += ' (%i/%i)' % (status['current_attempt'], status['max_attempts'])
        output.append('<tr><td class=dataVar><b>State:</b></td>')
        output.append('<td class=dataVal>%s (%s) [Duration: %s]</td></tr>\n' % \
                (states['service'][status['current_state']], type, 
                seconds_to_hms(start - status['last_hard_state_change'])))
        if status['current_state'] > 0:
            output.append('<tr><td class=dataVar><b>Acknowledged:</b></td>')
            if type == 'HARD' and status['acknowledgement_type']:
                ackstr = '<a href="%s" title="Remove Service Acknowledgement">Yes</a>' % \
                        (self_url + '&cmd=REMOVE_SVC_ACKNOWLEDGEMENT')
            elif type == 'HARD':
                ackstr = '<a href="%s" title="Acknowledge Service Problem">NO</a>' % \
                        (self_url + '&cmd=ACKNOWLEDGE_SVC_PROBLEM')
            else:
                ackstr = states['ack'][status['acknowledgement_type']]
            output.append('<td class=dataVal>%s</td></tr>\n' % (ackstr))
        if in_downtime:
            output.append('<tr><td class=dataVar valign=top><b>Downtime:</b></td>')
            if dt_comment == '_':
                output.append('<td class=dataVal valign=top>%s, ' % (dt_author))
            else:
                output.append('<td class=dataVal valign=top>%s, "%s" ' % (dt_author, dt_comment))
            output.append('&nbsp;&nbsp;- %s <a href="%s">' %
                    (str(datetime.datetime.fromtimestamp(dt_end)).split('.')[0],
                    self_url + '&cmd=DEL_SVC_DOWNTIME&args=downtime_id:%i' % (dt_id)))
            output.append('<img src="/nagios/images/disabled.gif" title="Remove Downtime"></a></td></tr>\n')

        output.append('<tr><td class=dataVar valign=top><b>Flapping:</b></td>')
        output.append('<td class=dataVal>' + flapping_state(object, status) + '</td></tr>\n')
        output.append('<tr><td class=dataVar valign=top><b>Output:</b></td>')
        output.append('<td class=dataVal><pre>%s' % (status['plugin_output']))
        output.append(status['long_plugin_output'].replace('\\n', '<br>') + '</pre></td></tr>\n')
        output.append('<tr><td class=dataVar valign=top><b>Servicegroups</b></td>')
        output.append('<td class=dataVal>')
        groups = []
        for group in sorted(object['groups']):
            groups.append('<a href="/nagios/cgi-bin/status.cgi?servicegroup=%s">%s</a>' %
                    (group, group))
        output.append(', '.join(groups))
        output.append('</td></tr>\n')

        output.append('</table>')

    output.append('</td></tr></table>')
    return (output, {'object': object, 'status': status})

def embed_contact(contact, object, status):
    '''take a contact, return output list and debug dict.'''
    output = []
    
    output.append('<table border=1 cellspacing=0 cellpadding=0 width=80% height=100%>')
    #output.append('<tr><td class=stateInfoTable1 bgcolor=f0f0f0>')
    output.append('<tr><td stateInfoTable1 bgcolor=f0f0f0>')
    output.append('<table border=0 width=100%><tr><td class=dataVal bgcolor=f0f0f0>')
    if not object.has_key('query_ok') or not object['query_ok']:
        output.append('<div class=serviceCRITICAL>Contact not found in Stats Daemon: %s</div>' % (contact))
    else:
        # CONTACT DATA
        output.append('You are: %s [%s]' % (linkify('mailto://%s' % (object['email']), contact),
                object['alias']))
        output.append('<br>&nbsp;&nbsp;- (<a href="/nagios/cgi-bin/config.cgi?type=contactgroups">%s</a>)<br><br>'
                % (', '.join(object['groups'])))
        output.append('&nbsp;Host Notification Period: %s (<i>%s</i>) [<b>%s</b>]<br>' % \
                (object['host_notification_period'],
                object['host_notification_options'],
                states['enabled'][object['host_notifications_enabled']]))
        if status.has_key('last_host_notification') and status['last_host_notification']:
            output.append('&nbsp;&nbsp;- Last Host Notification, %s ago<br>' % \
                    (seconds_to_hms(status['last_host_notification'], True)))
        output.append('&nbsp;Service Notification Period: %s (<i>%s</i>) [<b>%s</b>]<br>' % \
                (object['service_notification_period'],
                object['service_notification_options'],
                states['enabled'][object['service_notifications_enabled']]))
        if status.has_key('last_service_notification') and status['last_service_notification']:
            output.append('&nbsp;&nbsp;- Last Service Notification, %s ago<br>' % \
                    (seconds_to_hms(status['last_service_notification'], True)))
    output.append('</td></tr></table></td></tr></table>')
    
    return (output, {'object': object, 'status': status})


def main():
    global debug

    print 'Content-type: text/html\n\n'
    print '<html>'

    jira = True
    cacti = True
    banner = True
    args = ''

    if not form.has_key('host'):
        print '''<head><title>Nagios - Extended UI</title></head>
<body>
Error, No host passed
</body>
'''
    else:  # Host passed.

        # Set variables and collect initial data.

        if form.getvalue('debug'):
            debug = True
        if form.getvalue('jira'):
            jira = False
        if form.getvalue('cacti'):
            cacti = False
        args = form.getvalue('args', '')
        
        host = form.getvalue('host')
        host_o = get_nagiosstats('object host %s' % (host))
        host_o['comments'] = get_nagiosstats('status hostcomment %s' % (host)).get(host, [])
        host_o['groups'] = get_nagiosstats('object_index hostgroup_by_member %s' %
                (host)).get(host, [])
        host_o['servicegroups'] = get_nagiosstats('object_index servicegroup_by_member %s' %
                (host)).get(host, [])
        host_s = get_nagiosstats('status host %s' % (host))
        host_d = get_nagiosstats('status hostdowntime %s' % (host))
        contact = os.environ['REMOTE_USER']
        contact_o = get_nagiosstats('object contact %s' % (contact))
        contact_o['groups'] = get_nagiosstats('object_index contactgroup_by_member %s' % 
                (contact)).get(contact, [])
        contact_s = get_nagiosstats('status contact %s' % (contact))
        style = '''<LINK REL='stylesheet' TYPE='text/css' HREF='/nagios/stylesheets/common.css'>
        <LINK REL='stylesheet' TYPE='text/css' HREF='/nagios/stylesheets/extinfo.css'>
        <LINK REL='stylesheet' TYPE='text/css' HREF='/nagios/stylesheets/status.css'>
        <style>
            pre {
                white-space: pre-wrap; /* css-3 */
                white-space: -moz-pre-wrap !important; /* Mozilla, since 1999 */
                white-space: -pre-wrap; /* Opera 4-6 */
                white-space: -o-pre-wrap; /* Opera 7 */
                word-wrap: break-word; /* Internet Explorer 5.5+ */
            }
            .tab  { font-weight: bold; font-size: 110%; margin: 8px; padding: 8px; background-color: #e7e7e7; }
            .tabdata { font-weight: normal; color: #000000; }

        </style>'''
        tabs = []       # [{'header': 'blah', 'body': 'blah'},]
        if not form.has_key('service'):
            service = None
            service_d = []
            print '<head><title>Nagios - Extended UI [%s]</title>' % (host)
            print(style)
            print '</head>'
        else:
            service = form.getvalue('service')
            print '<head><title> Nagios - Extended UI [%s/%s]</title>' % (host, service)
            print(style)
            print '</head>'
            if service is not None:
                service = service.replace('+', ' ')
                service_o = get_nagiosstats('object service %s %s' % (host, service.replace(' ', '\\ ')))
                service_o['comments'] = get_nagiosstats('status servicecomment %s %s' % 
                        (host, service)).get(service, [])
                service_o['groups'] = get_nagiosstats('object_index servicegroup_by_member %s' %
                        ('%s/%s' % (host, service))).get('%s/%s' % (host, service), [])
                service_s = get_nagiosstats('status service %s %s' % (host, service.replace(' ', '\\ ')))
                service_d = get_nagiosstats('status servicedowntime %s %s' % (host, service.replace(' ', '\\ ')))

        print '<body class="status" onLoad="displayData(0);">'

        # Initialize command pipe.
        cmdfh = init_cmd(cmdfile)
        if cmdfh is None:
            print '<font color=#a00000><i>Command pipe initialization failed.'
            print 'Command submission disabled.</i></font>'

        if form.getvalue('cmd', False):
            (cmd_state, msg) = send_cmd(cmdfh, form.getvalue('cmd'), form.getvalue('args', []))
            print '<table border=1 cellspacing=0 cellpadding=0 width=98%><tr>'
            if not cmd_state:
                print '<td class=statusBGCRITICAL>'
                print msg
            else:
                print '<td class=statusBGWARNING>'
                print 'Submitted command "%s"<br>' % (form.getvalue('cmd'))
                print '&nbsp;- [%s]' % (msg)
                print 'It may take a couple minutes for command submission to be effective.'
            print '</td></tr></table><br>'

        # Extended service UI
        if service is not None:
            try:
                svcmod = __import__('extui.service.%s' % (service.replace(' ', '_')))
                # Why do we have to speify service.ServiceName here again?
                svcmod = getattr(svcmod.service, service.replace(' ', '_'))
            except:
                svcmod_output = []
                svcmod_debug = {}
            else:
                (svcmod_output, svcmod_debug) = svcmod.main(host, service, args)
                if svcmod_debug.has_key('nojira'):
                    jira = False
                if svcmod_debug.has_key('nocacti'):
                    cacti = False
                if svcmod_debug.has_key('nobanner'):
                    banner = False
                if svcmod_debug.has_key('tabs'):
                    for tab in scvmod_debug['tabs']:
                        tabs.append(tab)

        # Extended MetaVar UI
        mvmod_output = []
        mvmod_debug = []
        for key in [('_PORTFOLIO',), ('_PRODUCT',), ('_PURPOSE',), ('_PRODUCT', '_PURPOSE'),
                ('_HARDWARE',), ('_OS',), ('_SOURCE',)]:
            label = '_'.join(key).lower()[1:]
            keymod = ''
            ok = True
            for item in key:
                if item not in host_s.keys():
                    ok = False
                else:
                    keymod += host_s[item].replace('/', '_').split(' ', 1)[0].split(';',1)[1].lower() + '__'
            if not ok: continue
            keymod = keymod[:-2]
            try:
                # .../extui/metavar/portfolio/email_efficacy.py
                mv_mod = __import__('extui.metavar.%s.%s' % (label, keymod))
                mv_mod = getattr(mv_mod.metavar, label)
                mv_mod = getattr(mv_mod, keymod)
            except:
                pass
            else:
                try:
                    if service:
                        (o, d) = mv_mod.main(host, service, args, host_o, service_o)
                    else:
                        (o, d) = mv_mod.main(host, None, args, host_o, {})
                except:
                    d = {}
                    o = '<pre>ERROR running metamodule %s.%s</pre>' % (label, keymod)
                    if debug:
                        raise
                if d.has_key('nojira'):
                    jira = False
                if d.has_key('nocacti'):
                    cacti = False
                if d.has_key('nobanner'):
                    banner = False
                if d.has_key('tabs'):
                    for tab in d['tabs']:
                        tabs.append(tab)
                mvmod_output += o
                mvmod_debug.append(d)
                
            #print '<b>%s:<b> %s<br>' % (label, keymod) 
                    

        if banner:       
            #### TABLE.  Replace with something elegant?
            print '<table border=0 cellpadding=0 cellspacing=0 width=98%>'
            print '<tr><td valign=top width=49%>'
            (output, _debug) = embed_host(host, service, host_o, host_s, host_d, True, 
                    contact_o.get('can_submit_commands', 0))
            for l in output: print l
            if debug:
                print '<pre>'
                pprint(_debug)
                print '</pre>'

            print '</td><td valign=top width=49%><table border=0 cellpadding=0 cellspacing=0><tr><td>'
            if service is not None:
                (output, _debug) = embed_service(host, service, service_o, service_s,
                        service_d, True, contact_o.get('can_submit_commands', 0))
                for l in output: print l
                if debug:
                    print '<pre>'
                    pprint(_debug)
                    print '</pre>'
                print '<br>'
                print '<br>'
            print '</td></tr><tr><td width=49% valign=bottom align=right>'

            # Deal with Contact Block
            (output, _debug) = embed_contact(contact, contact_o, contact_s)
            for l in output: print l
            if debug:
                pprint(_debug)
            print '</td></tr><tr><td valign=bottom><br>'

        # output extended service ui here.
        if service is not None:
            for l in svcmod_output:
                print l
            if debug:
                pprint(svcmod_debug)

        # command block.
        if contact_o.get('can_submit_commands', 0) and banner:
            #print '</td></tr>'
            #print '<tr><td valign=bottom>'
            print '<table border=1 cellspacing=0 cellpadding=2 width=98% class=stateInfoTable1 align=right>'
            print '<tr><td>'
            print '<table border=0>'
            print '<tr><td class=dataVar valign=top><b>Comment<b></td>'
            print '<td class=dataVal>'
            print '<form href=%s>' % (self_url)
            print '<input type=hidden name=host value=%s>' % (host)
            if service is not None:
                print '<input type=hidden name=service value=%s>' % (service)
            print '<input type=radio name="cmd" value="ADD_HOST_COMMENT" checked>Host '
            if service is not None:
                print '<input type=radio name="cmd" value="ADD_SVC_COMMENT">Service'
            print '<br><input type=text name="comment_data" size=50>'
            print '<input type=submit value="Add">'
            print '</form>'
            print '</td></tr>'
            print '<tr><td class=dataVar valign=top><b>Downtime<b></td>'
            print '<td class=dataVal>'
            print '<form href=%s>' % (self_url)
            print '<input type=hidden name=host value=%s>' % (host)
            if service is not None:
                print '<input type=hidden name=service value=%s>' % (service)
            print '<input type=radio name="cmd" value="SCHEDULE_HOST_DOWNTIME" checked>Host & Services'
            if service is not None:
                print '<input type=radio name="cmd" value="SCHEDULE_SVC_DOWNTIME">Service '
            print '<br><input type=text name="start_time" size=50 value="%s">' % \
                    (datetime.datetime.fromtimestamp(int(time.time())))
            print '<font size=-1 color=505050>[start_time]</font>'
            print '<br><input type=text name="end_time" size=50 value="%s">' % \
                    (datetime.datetime.fromtimestamp(int(time.time()+5400)))
            print '<font size=-1 color=505050>[end_time]</font>'
            print '<input type=submit value="Add">'
            print '</form>'
            print '</td></tr></table>'
            print '</td></tr></table>'
            
        elif banner:
            print 'Command submission disabled for this Contact.'


        print '</td></tr></table></td></tr></table><br>'

        # output extended metavar ui here.
        for l in mvmod_output:
            print l
        if debug:
            for d in mvmod_debug:
                pprint(d)

        # JIRA, also the prototype of the templating system
        if jira:
            try:
                import extui.jira
            except:
                print '<!-- Err with jira import -->'
                if debug:
                    pprint(sys.path)
                    raise
            else:
                # prints normal output, returns debug structures.
                (output, _debug) = extui.jira.main(host, service)
                for l in output: print l
                if debug:
                    print '<pre>'
                    pprint(_debug)
                    print '</pre>'

        # manage comments.
        if len(host_o['comments']) or (service is not None and len(service_o['comments'])):
            types = {1: 'User Comment', 2: 'Scheduled Downtime', 3: 'Flapping', 4: 'Acknowledgement'}
            oddclass = {True: 'commentOdd', False: 'commentEven'}
            odd = False
            comments = '<table width=98% border=0 class=comment>'
            comments += '<thead>'
            comments += '<tr class=comment><th class=comment>Entry Time</th><th class=comment>Author</th>'
            comments += '<th class=comment>Comment</th><th class=comment>Type</th>'
            comments += '<th class=comment>Actions</th></tr></thead>'
            comments += '<tbody>'
            for comment in host_o['comments']:
                comments += '<tr class=%s><td class=%s>%s</td>' % \
                        (oddclass[odd], oddclass[odd], datetime.datetime.fromtimestamp(comment['entry_time']))
                comments += '  <td class=%s>%s</td>' % \
                        (oddclass[odd], quote(comment['author'], qsafe))
                try:
                    x = int(str(comment['comment_data']).split('-', 1)[1])
                except (IndexError, ValueError, TypeError, AttributeError):
                    comments += '  <td class=%s>%s</td>' % \
                            (oddclass[odd], quote(str(comment['comment_data']).replace('"', '\\"'), qsafe))
                else:
                    # Looks like a jira url.  link it
                    comments += '  <td class=%s><a href=https://jira.sco.cisco.com/browse/%s>%s</a></td>' % \
                            (oddclass[odd], comment['comment_data'], comment['comment_data'])
                comments += '  <td class=%s>Host, %s</td>' % (oddclass[odd], types[comment['entry_type']])
                comments += '  <td class=%s><a href=%s&cmd=DEL_HOST_COMMENT&args=comment_id:%s>' % \
                        (oddclass[odd], self_url, int(comment['comment_id']))
                comments += '<img src=/nagios/images/delete.gif border=0 title=Delete></td></tr>'
                odd = not odd
            if service is not None:
                for comment in service_o['comments']:
                    comments += '<tr class=%s><td class=%s>%s</td>' % \
                            (oddclass[odd], oddclass[odd], datetime.datetime.fromtimestamp(comment['entry_time']))
                    comments += '  <td class=%s>%s</td>' % \
                            (oddclass[odd], quote(comment['author'], qsafe))
                    try:
                        x = int(comment['comment_data'].split('-', 1)[1])
                    except (IndexError, ValueError, TypeError, AttributeError):
                        try:
                            comments += '  <td class=%s>%s</td>' % \
                                    (oddclass[odd], quote(comment['comment_data'].replace('"', '\\"'), qsafe))
                        except AttributeError:
                            comments += '  <td class=%s>%s</td>' % \
                                    (oddclass[odd], comment['comment_data'])
                            
                    else:
                        # Looks like a jira url.  link it
                        comments += '  <td class=%s><a href=https://jira.sco.cisco.com/browse/%s>%s</a></td>' % \
                                (oddclass[odd], comment['comment_data'], comment['comment_data'])
                    comments += '  <td class=%s>Service, %s</td>' % (oddclass[odd], types[comment['entry_type']])
                    comments += '  <td class=%s><a href=%s&cmd=DEL_SVC_COMMENT&args=comment_id:%s>' % \
                            (oddclass[odd], self_url, int(comment['comment_id']))
                    comments += '<img src=/nagios/images/delete.gif border=0 title=Delete></td></tr>'
                    odd = not odd

            comments += '</table>'

            tabs.insert(0, {'header': 'Comments', 'body': comments})

        if service is not None and service_o.has_key('notes_url'):
            tabs.append({'header': 'Service Runbook',
                        'body': '<iframe src=%s width=98%% height=1000><p>No iframe support</p></iframe>' %
                                (service_o['notes_url'].replace('opswiki', 'stbuops'))})

        # Cacti!
        # put all this in a module.
        if cacti:
            try:
                import extui.cacti
            except:
                print '<!-- Err with cacti import -->'
                if debug:
                    pprint(sys.path)
                    raise
            else:
                if service:
                    (output, _debug) = extui.cacti.main(host, service, host_s, service_s)
                else:
                    (output, _debug) = extui.cacti.main(host, None, host_s, {})
                for l in output: print l
                if debug:
                    print '<pre>'
                    pprint(_debug)
                    print '</pre>'
                if _debug.has_key('tabs'):
                    for tab in _debug['tabs']:
                        tabs.append(tab)

        # display bottom tab block.
        if len(tabs):
            print '<hr>'
            print '<script>'
            print '    var data = new Array()'
            print '    var tab = new Array()'

            for tab in tabs:
                print '    data[%i] = "' % (tabs.index(tab)),
                for line in tab['body'].lstrip('\n').replace('\r', '').split('\n'):
                    # move (Machine bits into esa log collection code!
                    if line and '(Machine' not in line and line != tab['header']:
                        sys.stdout.write(line + '<br>')
                print '";'
            print '''    function displayData(tabnum) {
        if (tabnum < data.length) {
            document.getElementById("data").innerHTML = data[tabnum];
        } else {
            document.getElementById("data").innerHTML = data[0];
        }
        for (i=0; i<=5; i++) {
            if (i == tabnum) {
                document.getElementById("tab"+i).style.background = "#f4f2f2";
                document.getElementById("tab"+i).style.border = "#d0d0d0 solid 1px";
            } else {
                document.getElementById("tab"+i).style.background = "#e7e7e7";
                document.getElementById("tab"+i).style.border = "#ffffff solid 1px";
            }
        }'''
            
            for tab in tabs:
                # clear all
                print ' ' * 8 + 'tab%i.class = "tab";' % (tabs.index(tab))
            print '    }'
            print '</script>'

            print '<table width="98%" border=0 cellspacing=2><tr>'
            for tab in tabs:
                tabstr = '<td align=left id="tab%i" class="tab" onClick="displayData(%i);"' + \
                        'width="%s%%">[%s]</td>'
                print tabstr % (tabs.index(tab), tabs.index(tab), int(99/len(tabs)), tab['header'])
            print '</tr>'
            print '<td colspan="%i"><div id="data" class="tabdata"></div></td>' % (len(tabs))
            print '</table>'


try:
    main()
except:
    print '<pre>'
    raise

#print cgi.print_environ()

print '<br><br>page generated in %0.4fs' % (time.time() - start)
print '</body></html>'

