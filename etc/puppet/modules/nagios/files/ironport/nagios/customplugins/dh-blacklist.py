#!/usr/bin/python26

# -*- coding: ascii -*-

# Connects to atlas database, grabs list of ips, then checks those against a blacklist
# that it grabs via ssh.
# Mike "Shaun" Lindsey <miklinds@ironport.com> 6/8/2009

import base64
import os
import socket
import sys
import traceback
import time
import MySQLdb
import _mysql_exceptions
import re
import glob
import urllib
import bisect

from optparse import OptionParser

def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    usage = """usage %prog [options]"""
    parser = OptionParser(usage)
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="MySQL host to connect to.")
    parser.add_option("-d", "--db", type="string", dest="db",
                            default="atlas",
                            help="Database to connect to.")
    parser.add_option("-u", "--user", type="string", dest="user",
                            help="MySQL user to connect as.")
    parser.add_option("-p", "--password", type="string", dest="password",
                            help="MySQL password to use.")
    parser.add_option("-b", "--blacklist", type="string", dest="blacklist",
                            help="blacklist name")
    parser.add_option("-l", "--location", type="string", dest="location",
                            help="ssh host and location string 'host:dir'")
    parser.add_option("-P", "--poller", type="string", dest="poller",
                            default="mon2.soma.ironport.com",
                            help="Poller host.  Used for notification logic.")
    parser.add_option("-n", "--notification", action="store_true", dest="notification",
                            default=False,
                            help="Do notification, not check.")
    parser.add_option("-r", "--reverse", action="store_true", dest="reverse",
                            default=False,
                            help="Blacklist file stores ip addresses in reverse dotted quad.")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    global options
    (options, args) = parser.parse_args()
    exitflag = 0
    if not options.host:
        exitflag = 1
	print "--host is not optional"
    if not options.user:
        exitflag = 1
	print "--user is not optional"
    if not options.password:
        exitflag = 1
	print "--password is not optional"
    if not options.blacklist:
        exitflag = 1
	print "--blacklist is not optional"
    if not options.location:
        exitflag = 1
	print "--location is not optional"
    if exitflag > 0:
        print
        parser.print_help()
        sys.exit(3)
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

    return options

def init_db():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    try:
        conn = MySQLdb.connect (host = options.host,
                            user = options.user,
                            passwd = options.password,
                            db = options.db)
    except:
        print "MySQL connect error"
	sys.exit(exit['unkn'])
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return conn

def do_sql(sql):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    conn = init_db()
    cursor = conn.cursor()
    if options.verbose: print "%s, %s" % (sql, conn)

    cursor.execute(sql)
    val = cursor.fetchall()
    if options.verbose: print "Results:", val
    conn.commit()
    conn.close()
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return val

def get_iplist():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    sql = "SELECT ip FROM atlas_ipaddress"
    iplist = do_sql(sql)
    if not len(iplist):
        print "No ips pulled from Atlas DB!"
        sys.exit(3)
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return iplist

def get_blacklist_data():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    # replace with paramiko later?
    blacklist_data = ''
    grabfile = 1
    if os.path.exists('%s/%s' % (data_dir, options.blacklist)):
        mtime = os.stat('%s/%s' % (data_dir, options.blacklist))[8]
        if (starttime - mtime) < 3600:
            grabfile = 0
    if grabfile:
        try:
            (host, file) = options.location.split(':')
        except:
            print "Problem with location string %s" % options.location
            sys.exit(3)
        sshcmd = "/usr/bin/ssh nagios@%s '/bin/cat %s'" % (host, file)
        pid = os.fork()
        if pid:
            print "Refreshing Blacklist file"
            sys.exit(3)
        else:
            try:
                bldata = os.popen(sshcmd).readlines()
            except:
                print "Error runnning sshcmd %s" % (sshcmd)
                sys.exit(0)
            bldata.sort()
            fileout = open('%s/%s' % (data_dir, options.blacklist), 'w')
            for line in bldata:
                # for djbdns style BL with timestamps
                if line.count(':'): line = line.split(':')[0] + '\n'
                # for spamhaus BL with netmasks.  Need to fix logic to check for network ranges.
                if line.count('/'): line = line.split('/')[0] + '\n'
                fileout.write(line)
            fileout.close()
            sys.exit(0)

    blacklist_data = open('%s/%s' % (data_dir, options.blacklist), 'r').readlines()
    if not len(blacklist_data):
        print "Error reading from Blacklist cache."
        sys.exit(3)
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return blacklist_data
    
def do_notification():
    # Expect this to be run from mon1.soma.  all others run from mon2.soma
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    filescmd = "/usr/bin/ssh nagios@%s '/usr/bin/find %s/ -mtime +1 | " % (options.poller, data_dir)
    filescmd += "/usr/bin/xargs touch; /usr/bin/find %s/ -mmin -10 | " % (data_dir)
    filescmd += "/bin/grep -e [cur,new]/%s-' 2>/dev/null" % (options.blacklist)
    if options.verbose: print filescmd
    files = os.popen(filescmd).readlines()
    if len(files):
        for file in files:
            file = file.strip()
            ip = file.split('-')[1]
            url = "https://atlas.iphmx.com/atlas/customer_to_ip/%s/" % (ip)
            customer = response=urllib.urlopen(url).read()
            if "404" in customer:
                customer = "Django error grabbing customer name"
            print "%s (%s) on %s Blacklist." % (customer, ip, options.blacklist)
            try:
                os.popen("mv %s %s/cur/ 2>/dev/null" % (file, data_dir))
            except:
                if options.verbose: print "File %s not local." % (file)
            try:
                os.popen("/usr/bin/ssh nagios@%s 'touch %s; mv %s %s/cur/' 2>/dev/null" % (options.poller, file, file, data_dir))
            except:
                print "Failed to move %s."
    else:
        print "Something odd just happened.  Called do_notification() but no files found."
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

starttime = time.time()
init()
exit = {}
exit['ok'] = 0
exit['warn'] = 1
exit['crit'] = 2
exit['unkn'] = 3

data_dir = "/usr/local/ironport/nagios/var/dh_blacklist"
if options.notification:
    do_notification()
    sys.exit(0)

iplist = get_iplist()
bldata = get_blacklist_data()
if options.verbose: print "%s records in blacklist." % (len(bldata))

error = 0
new = 0
if options.verbose:
    count = 0
for ip in iplist:
    ip = ip[0]
    if options.reverse:
        revip = ip.split('.')
        revip.reverse()
        revip = '%s.%s.%s.%s' % (revip[0], revip[1], revip[2], revip[3])
    else:
        revip = ip
    if options.verbose:
        count += 1
        if ((count/100)*100) == count: print count
    file = "%s-%s" % (options.blacklist, ip)
    if '%s\n' % (revip) == bldata[bisect.bisect(bldata, '%s\n' % (revip))-1]:
        error += 1
        if options.verbose: print "Found ip %s in BL %s " % (ip, options.blacklist)
        if os.path.exists('%s/cur/%s' % (data_dir, file)):
            if options.verbose: print "File already in blacklist %s" % (options.blacklist)
            mtime = os.stat('%s/cur/%s' % (data_dir, file))[8]
            if (starttime - mtime) > 86400:
                try:
                    os.popen("/bin/touch %s/cur/%s" % (data_dir, file))
                    new += 1
                except:
                    if options.verbose:
                        print "Failure to update timestamp for %s, hopefully the notification check gets it." % (file)
        else:
            open('%s/new/%s' % (data_dir, file), 'w').close()
            new += 1
    else:
        if os.path.exists('%s/cur/%s' % (data_dir, file)):
            if options.verbose:
                print "Moving %s to old directory." % (file)
            try:
                os.popen("mv %s/cur/%s %s/old/ 2>/dev/null" % (data_dir, file, data_dir))
            except:
                if options.verbose:
                    print "File %s does not exist on localhost" % (file)

endtime = time.time()
seconds = endtime - starttime
if options.verbose: print "Runtime took %2.4s seconds." % (seconds)
if new:
    print "%s IPs found on %s Blacklist." % (error, options.blacklist)
    sys.exit(2)
elif seconds >= 45:
    print "%s IPs found on %s Blacklist, but runtime is %2.4s seconds.  Please tune logic." % (error, options.blacklist, seconds)
    sys.exit(1)
elif error:
    print "%s IPs found on %s Blacklist." % (error, options.blacklist)
    sys.exit(0)
else:
    print "No IPs currently on %s Blacklist." % (options.blacklist)
    sys.exit(0)


print "Something odd just happened."
sys.exit(3)
