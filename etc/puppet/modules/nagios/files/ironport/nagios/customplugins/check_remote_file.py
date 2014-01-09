#!/usr/bin/python26 -u
"""Connect to a remote host, and check for file existance, size, or modification
time.  

Mike Lindsey <miklinds@cisco.com>  6/17/2010
"""
 
# -*- coding: ascii -*-

import warnings
warnings.filterwarnings('ignore', '.*', DeprecationWarning)
import paramiko
import sys
import time
import os

from optparse import OptionParser

def funcname():
    """so we don't have to keep doing this over and over again."""
    return sys._getframe(1).f_code.co_name

def init():
    """collect option information, display help text if needed, set up debugging,
            If no extra options passed, will throw critical if files are missing."""
    usage = "usage: %prog --host [host] --username [user] --password [pw] --file [file] [options]\n"
    usage += "example: %prog -H localhost -u nagios -p pw --file /etc/passwd --age 600"
    parser = OptionParser(usage=usage)
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="hostname to query.")
    parser.add_option("-u", "--username", type="string", dest="username",
                            help="username to login with, file or string.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="password to login with, file or string.")
    parser.add_option("-f", "--file", type="string", dest="file",
                            help="File, or CSV file list to query.")
    parser.add_option("-l", "--latest", action="store_true", dest="latest",
                            default=False,
                            help="""Treat --file as a directory (or list of dirs) and only check\
                                    the latest files in the directories.""")
    parser.add_option("-i", "--include", type="string", dest="include",
                            default=False,
                            help="""When checking a directory, only check files matching this\
                                    string.  CSV for multiples.""")
    parser.add_option("-e", "--exclude", type="string", dest="exclude",
                            default=False,
                            help="""When checking a directory, ignore files matching this\
                                    string.  CSV for multiples.""")
    parser.add_option("-a", "--age", type="string", dest="age",
                            help="""Critical error if file is older than this.\
                                    ##,## for warn,crit.""")
    # Can't think why we'd need this...
    #parser.add_option("-A", "--ageinvert", action="store_true", dest="ageinvert",
    #                        default=False,
    #                        help="Invert age test.")
    parser.add_option("-s", "--size", type="string", dest="size",
                            help="""Critical error if file is larger than this.\
                                    ##,## for warn,crit.""")
    parser.add_option("-S", "--sizeinvert", action="store_true", dest="sizeinvert",
                            default=False,
                            help="Invert size test.")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    error = 0
    if not options.host:
        sys.stderr.write("Missing --host\n")
        error += 1
    if not options.username:
	sys.stderr.write("Missing --username\n")
        error += 1 
    if not options.password:
	sys.stderr.write("Missing --password\n")
        error += 1
    if not options.file:
        sys.stderr.write("Missing --file\n")
        error += 1

    if options.age and options.age.count(',') > 1:
        sys.stderr.write("Don't know what to do with more than 2 entries for --age\n")
        error += 1
    if options.size and options.size.count(',') > 1:
        sys.stderr.write("Don't know what to do with more than 2 entries for --size\n")
        error += 1
    if options.size and options.size.count(',') == 1:
        (warn, crit) = options.size.split(',')
        warn = int(warn)
        crit = int(crit)
        if not options.sizeinvert and warn > crit:
            sys.stderr.write("Size warn must be less than crit.\n")
            error += 1
        elif options.sizeinvert and warn < crit:
            sys.stderr.write("Size warn must be larger than crit, when --sizeinvert passed.\n")
            error += 1
        
    if error:
        parser.print_help()
        sys.exit(3)
    try:
        password = open(options.password).read()
    except:
        if options.verbose: print "--password should be a file"
    else:
        options.password = password
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return options

def connect(hostname):
    """Connect and return a SSHClient object"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(hostname=hostname, username=options.username, \
            password=options.password, port=22, key_filename=os.path.expanduser("~nagios") + "/.ssh/id_rsa")
    sftp = client.open_sftp()

    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return sftp, client

def get_stat(client, file):
    """Hit a device and grab all the stats"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    stats = client.stat(file)
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() + 
                            "()\n")
    return stats

def get_latest(client, dir):
    """Open channel on transport, get dirlist, capture output and return"""
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() +
                            "()\n")
    if options.verbose: print 'DEBUG: Running dirlist on:', dir
    if not dir.endswith('/'):
        dir = dir + '/'
    #chan.setblocking(0)
    include = ''
    exclude = []
    if options.exclude:
        for item in options.exclude.split(','):
            if options.verbose:
                sys.stderr.write("Tacking %s onto exclude list.\n" % (item))
            exclude.append(item.strip('!'))
    if options.include:
        for item in options.include.split(','):
            if options.verbose:
                sys.stderr.write("Tacking %s onto include list.\n" % (item))
            include += '%s,' % (item) 
        if include.count(',') > 1:
            include = '*{%s}*' % (include[:-1])
        else:
            include = '*%s*' % (include[:-1])
    if not include:
        include = '*'
    if options.verbose:
        sys.stderr.write("ls -t %s%s\n" % (dir,include))
    stdin, stdout, stderr = client.exec_command("ls -dt %s%s" % (dir,include))
    out = ''
    if exclude:
        for line in stdout.readlines():
            ok = True
            for item in exclude:
                if item in line:
                    if options.verbose: 
                        sys.stderr.write("Found %s in %s, skipping.\n" % (item, line))
                    ok = False
                else:
                    if options.verbose:
                        sys.stderr.write("Did not find %s in %s, continuing.\n" % (item, line))
            if not ok:
                continue
            else:
                out = line
                break
    else:
        out = stdout.readline()
    out = out.rstrip()
    if dir not in out:
        out = dir + out
    if options.verbose: sys.stderr.write(">>DEBUG end   - " + funcname() +
                            "()\n")
    return out

if __name__ == '__main__':
    exitcode = 3
    options = init()

    logfile = '/dev/null'
    try:
        paramiko.util.log_to_file(logfile)
    except:
        if options.verbose:
            print "Unable to open logfile %s" % (logfile)
        try:
            paramiko.util.log_to_file('/dev/null')
        except:
            print "Also unable to redirect logging to /dev/null"

    error_str = ''
    try:
        sftp, client = connect(options.host)
    except:
        print "Error connecting to %s" % (options.host)
        sys.exit(3)
    files = {}
    crit_string = ''
    warn_string = ''
    ok_string = ''

    for file in options.file.split(','):
        if options.latest:
            dir = file
            file = get_latest(client, dir)
            if dir.strip('/') == file.strip('/'):
                crit_string += "No files matching pattern in directory %s\n" % (dir)
                continue
        try:
            filestat = get_stat(sftp, file)
        except:
            crit_string += "File %s missing\n" % (file)
        else:
            if not options.age and not options.size:
                ok_string += "File %s present on host\n" % (file)
            if options.age:
                if options.age.count(','):
                    (warn, crit) = options.age.split(',')
                    crit = int(crit)
                    warn = int(warn)
                else:
                    crit = int(options.age)
                    warn = crit
                if (filestat.st_mtime > (time.time() - warn)):
                    ok_string += "File %s only %is old.\n" % \
                            (file, time.time() - filestat.st_mtime)
                elif (filestat.st_mtime < (time.time() - crit)):
                    crit_string += "Crit: File %s is %is (> %ss) old.\n" % \
                            (file, time.time() - filestat.st_mtime, crit)
                elif (filestat.st_mtime < (time.time() - warn)):
                    warn_string += "Warn: File %s is %is (> %ss) old.\n" % \
                            (file, time.time() - filestat.st_mtime, warn)
            if options.size:
                if options.size.count(','):
                    (warn, crit) = options.size.split(',')
                    crit = int(crit)
                    warn = int(warn)
                else:
                    crit = int(options.size)
                    warn = crit
                if not options.sizeinvert:
                    if (filestat.st_size < warn):
                        ok_string += "File %s only %sb\n" % \
                                (file, filestat.st_size)
                    elif (filestat.st_size > crit):
                        crit_string += "Crit: File %s is %sb (> %sb)\n" % \
                                (file, filestat.st_size, crit)
                    elif (filestat.st_size > warn):
                        warn_string += "Warn: File %s is %sb (> %sb)\n" % \
                                (file, filestat.st_size, warn)
                else:
                    if (filestat.st_size > warn):
                        ok_string += "File %s is %sb\n" % \
                                (file, filestat.st_size)
                    elif (filestat.st_size < crit):
                        crit_string += "Crit: File %s is %sb (< %sb)\n" % \
                                (file, filestat.st_size, crit)
                    elif (filestat.st_size < warn):
                        warn_string += "Warn: File %s is %sb (< %sb)\n" % \
                                (file, filestat.st_size, warn)

    if crit_string:
        sys.stdout.write(crit_string)
        sys.stdout.write(warn_string)
        sys.stdout.write(ok_string)
        sys.exit(2)
    elif warn_string:
        sys.stdout.write(warn_string)
        sys.stdout.write(ok_string)
        sys.exit(1)
    else:
        sys.stdout.write(ok_string)
        sys.exit(0)
