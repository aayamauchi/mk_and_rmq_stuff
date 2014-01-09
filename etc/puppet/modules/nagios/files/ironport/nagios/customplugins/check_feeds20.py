#!/usr/bin/python26

import sys, MySQLdb, getopt, getpass, time
import _mysql_exceptions


def usage():
    print "syntax: %s -H <host> -u <user> -p <password> -d <db> -f <feed name> [-v <version>]" % (sys.argv[0])
    print "   -v <version> - Valid values: 4.0, 4.1.  Defaults to 4.0"

def closeDB():
    global dbc
    global cursor
    cursor.close()
    dbc.close()

def active_ft():
    sql = """
    SELECT hostname,httpd_port
    FROM     feeds_ftdb.ft_node_status
    WHERE    node_state='active'
    LIMIT    1
    """
    
    cursor.execute(sql)
    active_server,http_port = cursor.fetchone()
    return active_server+":"+str(http_port)

def get_monitor_stats(cursor, mnemonic):
    """Get the monitor statistics for this feed.
    :return: A tuple of
        consec_warn, consec_page, percent_warn, percent_page, check_count,
        consec_failures, count_pass, count_fail, last_exception
    """

    assert mnemonic
    sql = """
    SELECT   consecutive_failures_warn,
             consecutive_failures_page,
             percentage_failures_warn,
             percentage_failures_page,
             percentage_check_count
    FROM     monitors
    WHERE    mnemonic = %s
    """

    cursor.execute(sql, (mnemonic,))
    if cursor.rowcount == 0:
        raise Exception, "No monitors for mnemonic %s" % (mnemonic, )

    consec_warn, consec_page, percent_warn, percent_page, check_count = \
      cursor.fetchone()

    sql = """
    SELECT   update_failures
    FROM     sources
    WHERE    mnemonic = %s 
    """

    cursor.execute(sql, (mnemonic,))
    consec_failures = cursor.fetchone()[0]

    sql = """
    SELECT   sum(if (res.success = 'pass', 1, 0)) as pass,
             sum(if (res.success = 'fail', 1, 0)) as fail
    FROM     (
              SELECT success FROM results
              WHERE  mnemonic = %s
              ORDER BY unixtime DESC
              LIMIT %s
             ) res
    """

    cursor.execute(sql, (mnemonic, check_count))
    count_pass, count_fail = cursor.fetchone()
    if not count_fail:
        count_fail = 0
    if not count_pass:
        count_pass = 0

    sql = """
    SELECT   exception
    FROM     results
    WHERE    mnemonic = %s
    AND      exception IS NOT NULL
    ORDER BY unixtime DESC
    LIMIT    1
    """

    cursor.execute(sql, (mnemonic, ))
    if cursor.rowcount == 1:
        last_exception = cursor.fetchone()[0]
    else:
        last_exception = None

    return consec_warn, consec_page, percent_warn, percent_page, check_count, \
        consec_failures, count_pass, count_fail, last_exception
# End of get_monitor_stats

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'H:u:p:d:f:v:h')
except getopt.GetoptError, inst:
    usage()
    sys.exit(2)

host = 'localhost'
user = getpass.getuser()
passwd = None
db = None
warningThreshold = None
criticalThreshold = None
version = "2.0"
start_time = time.time()


for opt, arg in optlist:
    if opt =='-h':
        usage()
        sys.exit(2)
    if opt =='-H':
        host = arg
    if opt =='-u':
        user = arg
    if opt =='-p':
        passwd = arg
    if opt =='-d':
        db = arg
    if opt == '-f':
        feedname = arg
    if opt == '-v':
        version = arg

try:
    dbc = MySQLdb.connect(user=user, passwd=passwd, db=db, host=host)
except _mysql_exceptions.OperationalError, inst:
    print "MySQL Error:", inst
    usage()
    sys.exit(2)

cursor = dbc.cursor()

consec_warn, consec_page, percent_warn, percent_page, check_count, \
    consec_failures, count_pass, count_fail, last_exception = \
    get_monitor_stats(cursor,feedname)

total_results =  int(count_pass) + int(count_fail)


if total_results == 0:
    percent_failure=100
    result = 3
else:
    percent_failure = 100 * int(count_fail) / total_results
    if consec_failures >= consec_page or percent_failure > percent_page:
        result = 2
    elif consec_failures >= consec_warn or percent_failure > percent_warn:
        result = 1
    else:
        result = 0

end_time = time.time()
total_time = end_time - start_time
#print "Time - ", total_time

if result:
    active_server="http://"+active_ft()+"/feedStatus"

    if last_exception is None:
    	last_exception=active_server
    else:
    	last_exception=last_exception+"-"+active_server

    #Prefix with feedname
    last_exception="Feeds:"+feedname+":"+last_exception

    #Remove line endings
    last_exception=last_exception.replace("\n"," ")

    print last_exception

else:
    print "Success - "+feedname

closeDB()

sys.exit(result)

