#!/usr/bin/env python26

from email import message_from_string
from time import time, sleep, ctime, strptime, mktime
from tempfile import mkstemp
from os import fdopen, close, write, path
from simplejson import loads, dumps
from hashlib import md5
from subprocess import Popen, PIPE
from shlex import split
import sys

def format_passive_result(host, svc, msg, code, t):
    """Return the proper contents for a Passive check result file."""
    result = '### Passive Check Result ###\n'
    result += '# Time: %s\n' % (ctime(t))
    result += 'file_time=%i\n\n' % (t)
    result += '### Nagios Service Check Result ###\n'
    result += 'host_name=%s\n' % (host)
    result += 'service_description=%s\n' % (svc)
    result += 'check_type=1\n'
    result += 'check_options=1\n'
    result += 'scheduled_check=0\n'
    result += 'reschedul_check=0\n'
    result += 'latency=0.0\n'
    result += 'start_time=%f\n' % (t)
    result += 'finish_time=%f\n' % (t)
    result += 'early_timeout=0\n'
    result += 'exited_ok=1\n'
    result += 'return_code=%i\n' % (code)
    result += 'output=%s\n\n' % (msg.replace('\n', '\\n'))

    return result

def load_config(input, configfile):
    error = False
    
    cfh = open(configfile)
    config = cfh.read()
    config = config.split('\n')
    cleantemp = ''
    for line in config:
        if not line.startswith('#'):
            cleantemp += line
    config = cleantemp
    config = loads(config)
    for key in sorted(config.keys()):
        x = 0
        y = len(config[key]['Text'].split())
        words = input.split()
        for word in config[key]['Text'].split():
            if word[0] == '$':
                config[key][word[1:]] = input.split()[x]
            elif word.lower() != words[x].lower():
                break
            x += 1

        if x == y:
            config[key]["Key"] = key # Add the key to the hash
            if "Stateful" not in config[key].keys():
                config[key]["Stateful"] = 0
            return config[key]

    return {'Stateful': 0, 'Text': '$text', 'Time': '15', 'Code': 'CRITICAL-EMAIL-ALERTS',
            'Key': 'ZZ.UNKN'}
    
if __name__ == '__main__':
    """Read message from STDIN.  Check against list, submit if needed."""
    msg = sys.stdin.read()

    msg = message_from_string(msg)

    if not msg.has_key('Subject'):
        print "Invalid message"
        sys.exit(2)
    svc = 'AsyncOS-Email_Alert'
    try:
        seve = msg['Subject'].split()[0]
        host = msg['Subject'].split()[2].strip(':').lower()
        type = msg['Subject'].split()[1].strip('<>')
    except:
        print 'Error parsing subject: %s' % (msg['Subject'])
        sys.exit(2)

    body = msg.get_payload().split('message is:')[1].split('Version:')[0].strip()
    config = load_config(body, '/usr/local/ironport/nagios/mail/CES_Alert/CES_Alert.cfg')
    print config
    if 'Severity' in config:
        seve = config['Severity']

    statefile = '/usr/local/ironport/nagios/mail/CES_Alert/CES_Alert.state'
    try:
        sf = open(statefile, 'r')
        state = loads(sf.read())
        sf.close()
    except:
        state = {}

    if config.get('Stateful', 0) or config.get('Time', 0):
        if not int(config.get('Recovery', 0)):
            if '%s %s' % (host, config['Code']) in state:
                # pre-existing event.
                date = state['%s %s' % (host, config['Code'])]
                event = md5('%s %s %s' % (host, config['Code'], date)).hexdigest()
            else:
                # new event
                date = msg['Date']
                event = md5('%s %s %s' % (host, config['Code'], date)).hexdigest()
                # update the statefile
                sf = open(statefile, 'w')
                state['%s %s' % (host, config['Code'])] = date
                sf.write(dumps(state))
                sf.close()
            if int(config.get('Time', 0)):
                _date = int(mktime(strptime(date.rsplit(' ',1)[0], '%d %b %Y %H:%M:%S')))
                _date2 = int(mktime(strptime(msg['Date'].rsplit(' ',1)[0], '%d %b %Y %H:%M:%S')))
                _time = int(config['Time']) * 60
                if _date == _date2:
                    print 'First occurrence.'
                    seve = 'Warning'
                elif (_date2 - _date) > _time:
                    print 'Multiple occurrence not within time window.'
                    seve = 'Warning'
        else:
            # get the last event date in order to generate a consistent event id.
            if '%s %s' % (host, config['Code']) in state:
                date = state['%s %s' % (host, config['Code'])]
                event = md5('%s %s %s' % (host, config['Code'], date)).hexdigest()
                # update the statefile, delete the last key.
                sf = open(statefile, 'w')
                del state['%s %s' % (host, config['Code'])]
                sf.write(dumps(state))
                sf.close()
            else:
                # recovery and no previous key.  We're done here.
                print "Recovery and no previous key."
                sys.exit(0)
    else:
        date = msg['Date']
        event = md5('%s %s %s' % (host, config['Code'], date)).hexdigest()

    start = int(mktime(strptime(date.rsplit(' ',1)[0], '%d %b %Y %H:%M:%S')))
    last  = int(mktime(strptime(msg['Date'].rsplit(' ',1)[0], '%d %b %Y %H:%M:%S')))
    body += ' \nCode:%s Event:%s Severity:%s Stateful:%s Start:%s Last:%s Recovery:%s' % \
            (config['Code'], event, seve, config.get('Stateful', 0), start, last, config.get('Recovery', 0))

    if seve in ['Critical', 'Major']:
        ret = 2
    else:
        ret = 1
    
    try:
        cfg = open('/usr/local/nagios/etc/nagios.cfg', 'r')
    except:
        print "Critical error opening config file."
        sys.exit(2)


    rpath = cfg.read().split('check_result_path=')[1].split()[0]
    cfg.close()

    # open twice, close the fd.  direct fd operations failing for some reason.
    (fd, file) = mkstemp(prefix='c', dir=rpath)
    close(fd)

    fh = open(file, 'w')

    print "opened %s for write" % (file)
    print format_passive_result(host, svc, body, ret, time())

    fh.write(format_passive_result(host, svc, body, ret, time()))
    fh.close()


    open(file + '.ok', 'w').close()
    sleep(0.2)

    # Service has is_volatile set, so if two email alerts trigger at or near the same time,
    # both will still get logged and alerted on.
    # 
    # ... and return to Ok state.

    if path.exists('/usr/bin/at'):
        atbin = '/usr/bin/at'
    else:
        atbin = '/bin/at'
    at = Popen(split(atbin + ' now + 30 minutes'), stdin=PIPE)
    
    input = '/usr/local/ironport/nagios/mail/CES_Alert/clear.sh %s %s %s'
    input = input % (host, svc, event)
    
    at.communicate(input=input)

    #(fd, file) = mkstemp(prefix='c', dir=path)
    #close(fd)

    #fh = open(file, 'w')

    #fh.write(format_passive_result(host, svc, body, 0, time()))
    #fh.close()

    #open(file + '.ok', 'w').close()

