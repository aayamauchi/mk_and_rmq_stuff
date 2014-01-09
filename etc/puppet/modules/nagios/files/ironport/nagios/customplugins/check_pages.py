#!/usr/bin/python26

import email, os, sys, getopt
from optparse import OptionParser


def usage():
    print "syntax: %s -d <MailDir> [-H <hostname> [-u <username>]]" % (sys.argv[0])


parser = OptionParser()
parser.add_option("-d", "--directory", dest="mailDir", help="Directory to check for messages.")
parser.add_option("-H", "--hostname", dest="host", help="Optional hostname to ssh to, otherwise use local host.")
parser.add_option("-u", "--nagios", dest="user", default="nagios", help="Optional user to ssh as, default: nagios.")
(options, args) = parser.parse_args()

if not options.mailDir:
    usage()
    sys.exit(2)


mailDir = options.mailDir
user = options.user
host = options.host

newMailDir = mailDir + "/new"

if host:
    newMailFiles = os.popen('/usr/bin/ssh %s@%s "ls %s"' % (user, host, newMailDir)).readlines()
else:
    newMailFiles = os.listdir(newMailDir)

if newMailFiles == []:
    print "OK - No new incoming pages."
    sys.exit(0)

summary = []
msgCount = 0
fromHdr = None
subjectHdr = None

for file in newMailFiles:
    if host:
        fd = os.popen('/usr/bin/ssh %s@%s "cat %s/%s"' % (user, host, newMailDir, file))
    else:
        fd = open(newMailDir + "/" + file)
    msg = email.message_from_file(fd)

    if msg.has_key('From'): fromHdr = msg['From'].rstrip()
    if msg.has_key('Subject'): subjectHdr = msg['Subject'].rstrip()


    summary.append("[%d %s: %s]" % (msgCount, fromHdr, subjectHdr))
    msgCount = msgCount + 1

print str(msgCount) + " messages: " + ' '.join(summary)
sys.exit(2)
