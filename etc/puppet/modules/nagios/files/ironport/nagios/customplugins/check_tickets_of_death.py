#!/usr/bin/python26
"""
    Alert monitor for active oversized tickets, itckets of death,
    with over alert_threshold Attachment rows.
"""

import sys
import time

import MySQLdb

db_host = ''
db_user = ''
db_password = '' 
db_name = ''
operation = ''
# counter_name = ''
operation_params = []
null_row0 = [0, '', 0, 0, 0]
attc_threshold=1000
alert_threshold=attc_threshold

def connect_db():
    return MySQLdb.connect(host=db_host, user=db_user, passwd=db_password, db=db_name)

def get_value():
    conn = connect_db()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute("""SELECT tr.Ticket, t.Status, t.Created, t.LastUpdated, COUNT(*) AS 'AttachmentCount' 
                    FROM rt3.Tickets t, rt3.Transactions tr, rt3.Attachments at 
                    WHERE tr.id=at.TransactionId AND tr.Ticket=t.id AND t.LastUpdated > date_sub(now(),INTERVAL 1 HOUR) 
		    AND t.Status != 'rejected'
                    GROUP BY tr.Ticket, t.Created 
                    HAVING COUNT(*) > %i """ % alert_threshold)

            # cursor.execute("""SELECT value, mtime, mby, hostname, pid FROM ft_counts WHERE counter_name = %s""", counter_name)
    
            rows = cursor.fetchall()
            if rows:
                # print rows[0]
                return rows[0]
            else:
                # print 'No rows'
                return null_row0

        finally:
            cursor.close()
    finally:
        conn.close()

def print_usage():
    print 'Usage: %s' % (sys.argv[0])
    print ' or'
    print '       %s <db_host> <db_user> <db_password> <db_name>' % (sys.argv[0])


def parse_argv(argv):
    global db_host, db_user, db_password, db_name 
    # global operation, counter_name, operation_params

    if (len(argv) != 5):
        print '%s needs 4 parameters' % (argv[0])
        print_usage()

        print 'LenArgv:', len(argv) -1

        return 2

    db_host, db_user, db_password, db_name = argv[1:5]

    if not ((len(db_host) > 2 and len(db_user) > 2 and len(db_password) > 2 and len(db_name) >= 1 )):
        print 'Invalid parameters!'
        print_usage()
        return 3

    return 0
    
def main(argv):
    ret_code = parse_argv(argv)
    if ret_code:
       return ret_code

    tckt, stts, crtd, lstu, attc = get_value()

    if attc > alert_threshold:
        print 'CRITICAL - value: ', attc,
        print 'threshold: ', alert_threshold,
        print 'host: ', db_host
        return 2
    else:
        print 'OK - value: ', attc,
        print 'threshold: ', alert_threshold,
        print 'host: ', db_host
        return 0
        

if __name__ == '__main__':
    try:
        ret_code = main(sys.argv)
    except:
        import traceback
        traceback.print_exc()
        ret_code = 2
    sys.exit(ret_code)
