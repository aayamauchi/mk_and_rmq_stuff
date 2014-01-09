#!/usr/bin/python26 -u
"""Script for running a service check against a cluster of hosts.

Mike Lindsey <miklinds@cisco.com>  11/3/2010
"""
 
# -*- coding: ascii -*-

import sys
import os
import time
import subprocess
import shlex
import threading

import asdb

from optparse import OptionParser

def funcname():
    """so we don't have to keep doing this over and over again."""
    return sys._getframe(1).f_code.co_name

def init():
    """collect option information, display help text if needed, set up debugging"""
    usage = """usage: %prog --product [product] --purpose [purpose] -s [script] -a '[args]'
        Warning and Critical thresholds, if passed have two formats, either
        integer or float.  If integer, then that many failures will result in
        that error level.  If a float, then that is treated as a percent;
        '0.80' == 80%.  If it is not passed, then any warning or critical will
        trigger an error of that level.
        Warnings will never trigger a critical event, but Unknowns can, if --critical
        is passed and there are more critical+unknown events than the threshold."""
    parser = OptionParser(usage=usage)
    parser.add_option("--product", type="string", dest="product",
                            help="Cluster Product")
    parser.add_option("--purpose", type="string", dest="purpose",
                            help="Cluster Purpose")
    parser.add_option("--environment", type="string", dest="environment",
                            default="prod",
                            help="Cluster Environment, Default: prod")
    parser.add_option("--location", type="string", dest="location",
                            help="Cluster Location")
    parser.add_option("-s", "--script", type="string", dest="script",
                            help="Monitoring Script")
    parser.add_option("-a", "--args", type="string", dest="args",
                            help="Script Arguments, %HOST% for end-host hostname.")
    parser.add_option("-w", "--warning", type="string", dest="warning",
                            help="Warning threshold.")
    parser.add_option("-c", "--critical", type="string", dest="critical",
                            help="Critical threshold.")
    parser.add_option("-t", "--timeout", type="int", dest="timeout",
                            default=55,
                            help="Timeout for subscript threads.  Default: 55s")

    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    error = 0
    if not options.product:
        sys.stderr.write("Missing --product\n")
        error += 1
    if not options.purpose:
	sys.stderr.write("Missing --purpose\n")
        error += 1 
    if not options.script:
	sys.stderr.write("Missing --script\n")
        error += 1
    else:
        if not os.path.exists(options.script) or not os.access(options.script, os.X_OK):
            sys.stderr.write("--script '%s' missing or not executable.\n" % (options.script))
            error += 1
    if options.warning:
        try:
            x = float(options.warning)
        except:
            sys.stderr.write("Warning must be either an int or a float.\n")
    if options.critical:
        try:
            x = float(options.critical)
        except:
            sys.stderr.write("Critical must be either an int or a float.\n")
    if options.warning and options.critical and options.warning >= options.critical:
        sys.stderr.write("Warning must be less than critical\n")
        error += 1

    if options.critical:
        if '.' in options.critical:
            options.critical = float(options.critical)
        else:
            options.critical = int(options.critical)

    if options.warning:
        if '.' in options.warning:
            options.warning = float(options.warning)
        else:
            options.warning = int(options.warning)

    if error:
        parser.print_help()
        sys.exit(3)
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return options

#def run(host, script, args=None):
#    """Open channel on transport, run command, capture output and return"""
#    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
#                            "()\n")
#    if options.verbose: print 'DEBUG: Running cmd:', cmd
#    stdin, stdout, stderr = client.exec_command("%s" % (cmd))
#    
#    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
#                            "()\n")
#    return 0


class PollerThread(threading.Thread):
    """
    Thread poller calls, so high latency checks get completed in a timely fashion.
    """
    def __init__(self, host):
        threading.Thread.__init__(self)
        self.host = host
        self.returncode = -5
        self.killtries = 0
        self.done = False
        self.process = None

    def run(self):
        if options.args:
            args = options.args.replace('%HOST%', self.host)
        else:
            args = ''
        if options.verbose:
            print ">>", options.script, args
        args = shlex.split('%s %s' % (options.script, args))
        self.process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            self.returncode = self.process.wait()
        except:
            pass

if __name__ == '__main__':
    exitcode = 3
    options = init()
    max_killtries = 10

    unkn_str = ''
    crit_str = ''
    warn_str = ''
    perf_out = ['', '']
    ok_str = ''
    ok = 0
    warn = 0
    crit = 0
    unkn = 0
    total = 0
    done = 0

    start = time.time()

    thread_dict = {}

    is_crit = False
    is_unkn = False
    is_warn = False

    try:
        hostlist = asdb.cache('get_hosts_by_product', (options.product, options.environment,
                options.purpose, options.location, True)) # one hour cache
    except:
        unkn_str += "Error pulling hostlist from ASDB."
    else:
        outputs = {}

        for host in hostlist:
            if options.verbose:
                print "Beginning subprocess run for %s" % (host)
            thread_dict[host] = PollerThread(host)
            thread_dict[host].setName(host)
            thread_dict[host].start()
            time.sleep(0.05)

        # Loop over hosts, checking on progress of threads and their processes until they have all completed
        all_done = False
        while not all_done:
            all_done = True
            for host in hostlist:
                if not thread_dict[host].done:
                    if thread_dict[host].killtries >= max_killtries:
                        # Number of kill attempts on this host's thread process is too high, give up and mark host as done to avoid a deadlock
                        outputs[host] = 'UNKNOWN - (Cluster check timed out after %is: **unable to kill subprocess**)\n' % (options.timeout)
                        thread_dict[host].done = True
                        thread_dict[host].returncode = 3
                    elif time.time() > (start + options.timeout):
                        # Timeout exceeded, try to kill thread's process and mark host done if the process was terminated
                        outputs[host] = 'UNKNOWN - (Cluster check timed out after %is)\n' % (options.timeout)
                        try:
                            thread_dict[host].process.kill()
                            thread_dict[host].killtries += 1
                        except:
                            pass
                        else:
                            time.sleep(0.05)
                        s = thread_dict[host].process.poll()
                        if s is not None:
                            thread_dict[host].done = True
                            thread_dict[host].returncode = 3
                        else:
                            all_done = False
                    elif thread_dict[host].returncode != -5 or not thread_dict[host].isAlive():
                        # Thread has completed its task, collect output and mark host as done
                        try:
                            outputs[host] = thread_dict[host].process.stdout.read()
                        except:
                            outputs[host] = '(null)\n'
                        thread_dict[host].done = True
                    else:
                        all_done = False
                        time.sleep(0.2)
                    
        for host in hostlist:
            total += 1
            output = outputs[host]
            if '|' in output:
                (output, perf) = output.split('|', 1)
                output += '\n'
            else:
                perf = ''
            if thread_dict[host].returncode == 3:
                unkn_str += "%s: %s" % (host, output)
                unkn += 1
            elif thread_dict[host].returncode == 2:
                crit_str += "%s: %s" % (host, output)
                crit += 1
            elif thread_dict[host].returncode == 1:
                warn_str += "%s: %s" % (host, output)
                warn += 1
            else:
                ok_str += "%s: %s" % (host, output)
                ok += 1
            if total == 1:
                perf_out[0] = perf.replace('=', '%i=' % (total))
            elif perf != '':
                perf_out[1] += perf.replace('=', '%i=' % (total))

    if options.critical:
        if isinstance(options.critical, int):    # integer
            if crit >= options.critical:
                is_crit = True
        else:                                    # float
            if (float(crit)/float(total)) >= options.critical:
                is_crit = True
        if crit > 0 and (crit + warn + unkn) == total:
            is_crit = True
    elif crit > 0:
        is_crit = True

    if not is_crit and options.warning:
        if isinstance(options.warning, int):      # integer
            if warn >= options.warning:
                is_warn = True
        else:                                     # float
            if (float(warn)/float(total)) >= options.warning:
                is_warn = True
        if warn > 0 and (warn + unkn) == total:
            is_warn = True
    elif not is_crit and warn > 0:
        is_warn = True

    if perf_out[1]:
        perf_out[1] = '| ' + perf_out[1]
    script = options.script.split('/')[-1]
    if (script == 'precache'):
        # when running under precache control, assume the real script path is in the first argument
        script = options.args.split()[0].split('/')[-1]
    ppe = '%s-%s-%s' % (options.product, options.environment, options.purpose)
    if is_crit:
        print "CRITICAL %s/%s -" % (crit, total),
        if warn:
            print "%s Warn" % (warn),
        if ok:
            print "%s Ok" % (ok),
        if unkn:
            print "%s Unkn" % (unkn),
        print "for %s on %s | %s" % (script, ppe, perf_out[0])
        print crit_str, warn_str, unkn_str, ok_str, perf_out[1]
        exitcode = 2
    elif is_warn:
        print "WARNING %s/%s -" % (warn, total),
        if crit:
            print "%s Crit" % (crit),
        if unkn:
            print "%s Unkn" % (unkn),
        if ok:
            print "%s Ok" % (ok),
        print "for %s on %s | %s" % (script, ppe, perf_out[0])
        print warn_str, crit_str, unkn_str, ok_str, perf_out[1]
        exitcode = 1
    elif unkn_str:
        print "UNKNOWN %s/%s -" % (unkn, total),
        if crit:
            print "%s Crit" % (crit),
        if warn:
            print "%s Warn" % (warn),
        if ok:
            print "%s Ok" % (ok),
        print "for %s on %s | %s" % (script, ppe, perf_out[0])
        print unkn_str, crit_str, warn_str, ok_str, perf_out[1]
        exitcode = 3
    else:
        print "OK %s/%s -" % (ok, total),
        if crit:
            print "%s Crit" % (crit),
        if warn:
            print "%s Warn" % (warn),
        if unkn:
            print "%s Unkn" % (unkn),
        print "for %s on %s | %s" % (script, ppe, perf_out[0])
        print ok_str, crit_str, warn_str, unkn_str, perf_out[1]
        exitcode = 0

    sys.exit(exitcode)
