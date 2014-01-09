#!/usr/bin/python26

import pickle
import nagiosplugin
import sys
import os
import stat
import urllib2
import cookielib
import time
import getpass
from xml.dom import minidom
import traceback
import socket
import time
import datetime

socket.setdefaulttimeout(2)

sys.stderr = sys.stdout # Redirect all output

from optparse import OptionParser


class AsyncCheck(nagiosplugin.Check):
    name = 'AsyncOS metric check'

    def __init__(self, optparser, logger):
        optparser.description = 'Check AsyncOS metrics via status XML'
        optparser.version = '1.0'
        optparser.add_option('-d', '--device', metavar='HOSTNAME',
                help='AsyncOS device hostname')
        optparser.add_option('-u', '--username', metavar='USER',
                help='AsyncOS device User for data collection.')
        optparser.add_option('-p', '--password', metavar='PW',
                help='AsyncOS device password for data collection.')
        optparser.add_option('-m', '--metric', metavar='METRIC',
                help='Metric to measure')
        optparser.add_option('-T', '--type', metavar='TYPE',
                default='gauge',
                help='Type of Metric [feature,counter,rate,gauge,auth]')
        optparser.add_option('-w', '--warning', metavar='RANGE',
                help='Warning threshold.  Seconds for features, Per-minute for counters, ' +
                'Per 15 minute for rates, and current for gauges. ' +
                'If threshold passed as three comma-separated numbers for rates, ' +
                'they are checked against the 1 minute, 5 minute, and 15 minute rates.')
        optparser.add_option('-c', '--critical', metavar='RANGE',
                help='Critical threshold.  Seconds for features, Per-minute for counters, ' +
                'Per 15 minute for rates, and current for gauges. ' +
                'If threshold passed as three comma-separated numbers for rates, ' +
                'they are checked against the 1 minute, 5 minute, and 15 minute rates.')
        optparser.add_option('-f', '--friendly', metavar='STRING',
                help='Friendly name for Metric.')
        optparser.add_option('-U', '--uom', metavar='STRING',
                help='Unit of measurement. ' +
                'Default for feature: seconds; counter,rate,gauge: metric.split("_")[-1]')
        optparser.add_option('-C', '--cookie', metavar='STRING',
                help='Default cookie cache location.',
                default='/usr/local/nagios/var/tmp')

    def process_args(self, options, args):
        '''Mangle options, pass back to self.'''
        self.device = options.device
        self.username = options.username
        self.password = options.password
        self.metric = options.metric
        self.type = options.type
        self.warning = options.warning
        self.critical = options.critical
        self.friendly = options.friendly
        self.verbose = options.verbose
        self.uom = options.uom
        self.cookie = options.cookie
        if self.metric is None and self.type != 'auth':
            print 'Must pass --metric'
            sys.exit(3)
        if self.type is not 'rate' and ((self.warning is not None and ',' in self.warning) or
                (self.critical is not None and ',' in self.critical)):
            print 'CSV thresholds only acceptable for rate style metrics'
            sys.exit(3)
        elif self.type is 'rate':
            error = False
            if self.warning.count(',') != 0 and self.warning.count(',') != 2:
                print '--warning must be single or triple value'
                error = True
            if self.critical.count(',') != 0 and self.critical.count(',') != 2:
                print '--critical must be single or triple value'
                error = True
            if error:
                sys.exit(3)

        self.realm = 'IronPort Web Interface'
        if self.uom is None:
            if self.type == 'feature':
                self.uom = 's'
            else:
                self.uom = self.metric.split('_')[-1]
                if self.uom == 'utilization':
                    self.uom = '%'
    
    def obtain_data(self):
        # Pull in the cookie cache, and use that if it's fresh.
        # nagiosplugin.Cookie uses exclusive locks, so don't keeo the file open.
        npcookiefile = '%s/npcookie.asyncos.%s' % (self.cookie, self.device)
        npcookie = nagiosplugin.Cookie(npcookiefile)
        data = npcookie.get()
        npcookie.close()
        if data is None:
            data = {}
        else:
            data = pickle.loads(data)
        if len(data.keys()):
            first = sorted(data.keys())[0]
            last = sorted(data.keys())[-1]
        else:
            first = 0
            last = 0
        if last + 60 < time.time() or self.type == 'auth':
            # most recent cookie in the jar is stale, grab new data.
            # always test for auth.
            url = 'https://%s/xml/status' % (self.device)
            handler = urllib2.HTTPBasicAuthHandler()
            handler.add_password(self.realm, self.device, self.username, self.password)

            # Update jar to save perisistently and reuse?
            jar = cookielib.FileCookieJar('%s/htcookie.asyncos.%s' % (self.cookie, self.device))

            opener = urllib2.build_opener(handler)
            urllib2.install_opener(opener)

            request = urllib2.Request(url)
            try:
                response = urllib2.urlopen(request)
            except urllib2.HTTPError:
                print 'Error connecting to Server:',
                print sys.exc_info()[1]
                sys.exit(2)
            except RuntimeError:
                print 'Authentication Error'
                if self.type == 'auth':
                    # auth fauilures are critical, always.
                    sys.exit(2)
                else:
                    sys.exit(3)
            except:
                print 'Error:',
                print '%s, %s' % (sys.exc_info()[0], sys.exc_info()[1])
                print '\n'.join(traceback.format_exc().split('\n')[:20])
                if self.type == 'auth':
                    # auth fauilures are critical, always.
                    sys.exit(2)
                else:
                    sys.exit(3)
            # handle http cookies
            jar.extract_cookies(response, request)

            datum = ''.join(response.readlines())
            # Only keep five items in the cache.
            if len(data) > 4:
                del data[first]
                first = sorted(data.keys())[0]
            outurl = 'https://%s/login?action=Logout' % (self.device)
            outrequest = urllib2.Request(outurl)
            jar.add_cookie_header(outrequest)

            # Current AsyncOS has an error that can occur on session logout.
            # Disable for now, and re-enable in a version or two.
            #try:
            #    out = urllib2.urlopen(outrequest)
            #except:
            #    #sys.stderr.write('Error logging out.  May have left stale session.\n')
            #    pass
            response.close()
            #out.close()
            opener.close()
            now = int(time.time())
            last = now
            if first == 0:
                first = now
            npcookie = nagiosplugin.Cookie(npcookiefile)
            npcookie.set(pickle.dumps(dict(data.items() + {now: datum}.items())))
            npcookie.close()
            # Shared cache  
            os.chmod(npcookiefile, stat.S_IRUSR|stat.S_IWUSR|stat.S_IRGRP|stat.S_IWGRP|stat.S_IROTH|stat.S_IWOTH)
            
            if self.type == 'auth':
                print 'Authentication Test OK'
                sys.exit(0)
            #sys.stderr.write('Stale cookie.  Refreshed.\n')
        else:
            # fresh cookie.  Eat it.
            #sys.stderr.write('Fresh cookie.  Ate it.\n')
            datum = data[last]

        self.value = None
        self.measures = []

        # it this moment all xml file placed in datum 
        dom = minidom.parseString(datum)
        if self.type == 'base':
            try:
                item = dom.getElementsByTagName(self.metric.split(':')[0])[0]
                self.value = item.getAttribute(self.metric.split(':')[-1])
            except:
                print "Error collecting base statistic."
                raise
            else:
                if self.metric == 'birth_time:timestamp':
                    # finding the birth_time
                    # it looks as <birth_time timestamp="20121106170214 (89d 18h 34m 37s)"/>
                    # so we grab birth_time value of ESA
                    start_time=int(time.mktime(datetime.datetime.strptime(self.value.split(' ')[0], "%Y%m%d%H%M%S").timetuple()))
                    # get current time
                    curr_time=int(time.time())
                    # calculate how long this esa working
                    live_time=curr_time - start_time
                    # and compare live_time with treshold. If esa lives less then treshold -- exit code should be critical.
                    if int(self.critical) < live_time:
                        # sending message with the NAgios Plugin API; see  http://pydoc.net/nagiosplugin/0.4.4/
                        self.measures.append(nagiosplugin.Measure(name=self.friendly or self.metric.split(':')[0],value=self.value))
                    else:
                        self.measures.append(nagiosplugin.Measure(name=self.friendly or self.metric.split(':')[0],value=self.value,critical=self.critical))
                else:
                    self.measures.append(nagiosplugin.Measure(name=self.friendly or self.metric.split(':')[0],
                        value=int(self.value), uom=self.uom, warning=self.warning, critical=self.critical))
                # break here
                return
        try:
            items = dom.getElementsByTagName('%ss' % (self.type))[0].getElementsByTagName(self.type)
        except IndexError:
            print 'Invalid value passed for --type'
            sys.exit(3)

        if self.type == 'feature':
            attr = 'time_remaining'
        elif self.type == 'counter':
            attr = 'lifetime'
        elif self.type == 'gauge':
            attr = 'current'

        for item in items:
            if item.getAttribute('name') == self.metric:
                if self.type != 'rate':
                    self.value = item.getAttribute(attr)
                    # Handle suffixes for log_used/available
                    if self.value[-1] == 'G':
                        self.value = int(self.value[:-1]) * 1024 * 1024 * 1024
                    elif self.value[-1] == 'M':
                        self.value = int(self.value[:-1]) * 1024 * 1024
                    elif self.value[-1] == 'K':
                        self.value = int(self.value[:-1]) * 1024

                    if self.type == 'counter':
                        self.value = int(self.value)
                        range = last - first
                        # Add some code to pick a better cookie if range is too large.
                        fdata = minidom.parseString(data[first])
                        fdata = dom.getElementsByTagName('%ss' % (self.type))[0].getElementsByTagName(self.type)
                        fvalue = item.getAttribute(attr)
                        self.value = int(round(self.value) - int(fvalue))

                        self.measures.append(nagiosplugin.Measure(name=self.friendly or self.metric, value=self.value,
                                uom=self.uom, warning=self.warning, critical=self.critical))
                    else:
                        if self.type == 'feature' and self.value == 'Dormant/Perpetual':
                            self.uom = ''
                            print self.default_message()
                            sys.exit(0)
                        self.value = int(self.value)
                        self.measures.append(nagiosplugin.Measure(name=self.friendly or self.metric, value=self.value,
                                uom=self.uom, warning=self.warning, critical=self.critical))
                else:
                    names = ['last_15_min']
                    if self.warning is None and ',' in options.critical:
                        names = ['last_1_min', 'last_5_min', 'last_15_min']
                        self.warning = [None, None, None]
                    elif self.warning is None:
                        self.warning = [None,]
                    elif ',' in self.warning:
                        names = ['last_1_min', 'last_5_min', 'last_15_min']
                        self.warning = self.warning.split(',')
                    elif self.critical is not None and ',' in self.critical:
                        self.warning = [self.warning] * 3
                    else:
                        self.warning = [self.warning]

                    if self.critical is None and len(self.warning) > 1:
                        self.critical = [None, None, None]
                    elif self.critical is None:
                        self.critical = [None,]
                    elif ',' in self.critical:
                        names = ['last_1_min', 'last_5_min', 'last_15_min']
                        self.critical = self.critical.split(',')
                    elif len(self.warning) > 1:
                        self.critical = [self.critical] * 3
                    else:
                        self.critical = [self.critical]
                    x = 0
                    for n in names:
                        self.value = item.getAttribute(n)
                        self.measures.append(nagiosplugin.Measure(name='%s in %s' % (self.metric, n),
                                value=int(self.value), uom=self.uom,
                                warning=self.warning[x], critical=self.critical[x]))
                        x += 1

        if not len(self.measures):
            print '%s %s not found.' % (self.type.capitalize(), self.metric)
            sys.exit(3)



    def default_message(self):
        return '[%s] %s %s %s'.rstrip() % (self.type, self.friendly or self.metric, self.value, self.uom)

if __name__ == '__main__':
    nagiosplugin.Controller(AsyncCheck)()
