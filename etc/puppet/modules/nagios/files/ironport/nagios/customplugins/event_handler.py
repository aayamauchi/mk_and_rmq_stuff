#!/usr/bin/env python26

import os
import sys
import traceback
from datetime import datetime
from subprocess import Popen, PIPE
from shlex import split

try:
    envs = sys.argv[1]
except:
    print "pass 'name:value|name2:value' pairs"
    print "ie: 'hostname:testhost|hostaddress:1.2.3.4|hoststate:DOWN|hoststatetype:SOFT|hostdowntime:0|hostattempt:2|maxhostattempts:3|hostoutput:output'"
    sys.exit()

e = {}
base    = '/usr/local/ironport/nagios/event_handler'
binpath = '/usr/local/ironport/nagios/bin'
pluginpath = '/usr/local/ironport/nagios/customplugins'
url     = 'https://mon.ops.ironport.com/nagios'

for env in envs.split('|'):
    (n, v) = env.split(':',1)
    e[n.lower()] = v

if os.getloadavg()[0] > 15.0:
    sys.exit(0)

try:
    name = e['hostname']
    if not e.has_key('servicestate'):
        # Host issue
        full  = name
        descr = e['hostaddress']
        state = e['hoststate']
        stype = e['hoststatetype']
        attempt = int(e['hostattempt'])
        attmax  = int(e['maxhostattempts'])
        downtime = int(e['hostdowntime'])
        output = e['hostoutput']
    else:
        # Service issue
        descr = e['servicedesc']
        full  = '%s/%s' % (name, descr)
        state = e['servicestate']
        stype = e['servicestatetype']
        attempt = int(e['serviceattempt'])
        attmax  = int(e['maxserviceattempts'])
        downtime = int(e['servicedowntime'])
        output = e['serviceoutput']
except KeyError:
    print 'please pass at minimum, hostname, address, state, state type, attempt,'
    print 'max attempts, downtime, and output'
    sys.exit(0)

#if state in ['CRITICAL', 'DOWN'] and not downtime and stype == 'SOFT':
if state in ['CRITICAL'] and not downtime and stype == 'SOFT':
    # determine if pageable
    if not e.has_key('servicestate'):
        cmd = '%s/nagios_escalation.py -H %s' % (binpath, name)
        _url = '%s/cgi-bin/extui.py?host=%s' % (url, name)
    else:
        cmd = '%s/nagios_escalation.py -H %s -S "%s"' % (binpath, name, descr)
        _url = '%s/cgi-bin/extui.py?host=%s&service=%s' % (url, name, descr)
    c = Popen(split(cmd), stdout=PIPE)
    (out, err) = c.communicate()
    if 'pager' in out:
        try:
            if attempt == '1':
                # Wall this host for early warning.
                c = Popen('/usr/bin/wall', stdin=PIPE)
                c.communicate(input='%s [%s/%s] \'%s\' %s' % (full, attempt, attmax, output, _url))
            elif attempt == (attmax - 1):
                # Notify IRC if almost paging.
                c = Popen(split('%s/ironcat.sh "%s [%i/%i] \'%s\' %s"' % 
                        (binpath, full, attempt, attmax, output, _url)))
                pass
        except:
            f = open('/tmp/handler.out', 'a')
            f.write('WALL and/or CAT problem.\n')
            f.write(traceback.format_exc())
            f.close()

        
if not downtime:
    if stype == 'HARD':
        script = '/usr/local/ironport/nagios/event_handler/%s/HARD/' % (state)
    else:
        script = '/usr/local/ironport/nagios/event_handler/%s/SOFT/%s/' % (state, attempt)

    if not e.has_key('servicestate'):
        script += name
    else:
        _script = script + name + '_' + descr.lower().replace(' ', '_').replace('/', '')
        if os.path.isfile(_script): # and os.access(_script, os.X_OK):
            script == _script
        else:
            script += descr.lower().replace(' ', '_').replace('/', '')
        
    date = datetime.now().ctime()

    # Generate nagios env vars for script (if called) and nagsub.py
    for key in e.keys():
        os.environ['NAGIOS_%s' % (key.upper())] = e[key]

    if os.path.isfile(script) and os.access(script, os.X_OK):
        # script exists, call it.
        c = Popen([script, name], stdout=PIPE, stderr=PIPE)
        (out, err) = c.communicate()
        f = open('/tmp/handler.out', 'a')
        f.write('[%s] %s %s\n' % (date, script, name))
        f.write('%s\n' % (out))
        f.write('%s\n\n' % (err))
        f.close()

        c = Popen('%s/nagsub.py' % (pluginpath), stdin=PIPE, stdout=PIPE, stderr=PIPE)
        (out, err) = c.communicate(input='%s\n%s\n%s' % (script, out, err))
    else:
        f = open('/tmp/handler.out', 'a')
        f.write('[%s] (no) %s %s\n' % (date, script, name))
        f.close()
        c = Popen('%s/nagsub.py' % (pluginpath), stdout=PIPE, stderr=PIPE)
        
