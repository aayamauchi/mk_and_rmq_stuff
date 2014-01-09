#!/usr/bin/python26
"""Monitor for feeds.

:$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/feeds_monitor.py#1 $
:$Author: miklinds $
:$Date: 2012/03/30 $

Returns:
- If querying a feed (as a 5th argument, followed by the required args)
   3 - UNKNOWN: usually due to errors (i.e. db errors)
   2 - CRITICAL: if the specified feed has not been running for long enough for
          paging, or has more consecutive failures than the paging threshold
   1 - WARNING: if the specified feed has not been running for long enough for
          warning, or has more consecutive failures than the warning threshold
   0 - OK: if none of the above, the feed is running normally
- If a feed is not specified:
  It will return the number of feeds running in 'sucess', 'warning' and
  'critical' states (i.e. sucess:0 warning:0 critical:6). If no cacti option
  is set, it will also return a value of CRITICAL, if any feed is critical. OK,
  if all feeds are ok, and 'WARNING' if at least one feed is in a warning state.
  All the feeds in CRITICAL state are also printed to std out
"""

import MySQLdb
import optparse
import sys
import time

# valid return values
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3


class FeedsMonitorError(Exception):
    pass


class FeedsMonitorHelpException(Exception):
    pass


class FeedsMonitor(object):
    """
    FeedsMonitor queries the specified database and returns the status of
    the given feed or stats of how many feeds are running in which states
    """

    def __init__(self):
        self.usage = \
            """usage: %prog [-v] [-C] dbhost dbname username password [feed]"""

        self.option_parser = optparse.OptionParser(self.usage)

        self.option_parser.add_option('-v', '--verbose', dest='verbose',
            action='store_true', default=False,
            help='verbose (debug) output')
        self.option_parser.add_option('-C', '--cacti', dest='cacti',
            action='store_true', default=False,
            help='cacti compatible output (incompatible with -v and [feed])')

        self.opts = None
        self.args = None
        self.feed = None
        self.retval = OK
        self.db_connection = None


    def print_verbose(self, string):
        """Print only if verbose flag is set"""
        if self.opts.verbose:
            print '[debug] ' + string


    def check_option_conflicts(self):
        """Check for any conficting options, and handle appropriately"""
        err_strings = []
        if self.opts.verbose and self.opts.cacti:
            err_strings.append(
                'options --cacti and --verbose are mutually exclusive')
        if self.opts.cacti and self.feed:
            err_strings.append(
                'option --cacti and feed argument are mutually exclusive')
        if err_strings:
            self.option_parser.error('\n'.join(err_strings))


    def parse_args(self):
        """Parse the command line.  Raise appropriate exceptions for invalid
        input.
        """
        (self.opts, self.args) = self.option_parser.parse_args()
        if len(self.args) == 5:
            self.feed = self.args[4]
        elif len(self.args) != 4:
            print self.usage
            raise FeedsMonitorError('ERROR: invalid number of arguments')
        self.check_option_conflicts()


    def setup_db_conn(self):
        """Initialize the db_connection."""
        try:
            # Arguments need to be in the order: dbhost, dbname, user, password
            self.db_connection = MySQLdb.connect(
                host=self.args[0],
                db=self.args[1],
                user=self.args[2],
                passwd=self.args[3]
                )
        except MySQLdb.Error, e:
            raise FeedsMonitorError(
                'ERROR opening database connection: %s' % (e,))


    def run_query(self, query):
        """Execute the specified query on the db"""
        cursor = self.db_connection.cursor()
        self.print_verbose('executing query: %s' % (query,))
        try:
            cursor.execute(query)
        except MySQLdb.Error, err:
            raise FeedsMonitorError('ERROR executing query: %s' % (str(err),))
        return cursor.fetchall()


    def get_feed_status(self, mnemonic):
        """Based on the different thresholds for periods without the feed
           being updated and its consecutive failures, it returns a status value
        """
        self.print_verbose('Getting status for feed: %s' % (mnemonic,))

        # get monitoring numbers for the given feed
        query = """
        SELECT  consecutive_failures_warn, consecutive_failures_page,
                no_update_period_warn, no_update_period_page, UNIX_TIMESTAMP()
        FROM    monitors
        WHERE   mnemonic='%s'""" % (mnemonic,)

        ret = self.run_query(query)[0]
        consecutive_failures_before_warn = int(ret[0])
        consecutive_failures_before_page = int(ret[1])
        no_update_period_before_warn = int(ret[2])
        no_update_period_before_page = int(ret[3])
        current_unix_ts = int(ret[4])

        # get 'sources' info
        query = """
        SELECT  last_update, update_failures, last_exception, disable_until
        FROM    sources
        WHERE   mnemonic='%s'""" % (mnemonic,)

        ret = self.run_query(query)[0]
        last_update = int(ret[0])
        update_failures = int(ret[1])
        last_exception = ret[2]
        disable_until = int(ret[3])

        return_value = OK
        if disable_until > current_unix_ts:
            message = '%s: OK - Disabled until %s' % \
                      (mnemonic, time.strftime('%m/%d/%y %H:%M:%S',
                                               time.gmtime(disable_until)))
        else:
            age = current_unix_ts - last_update

            message = '%s: OK' % (mnemonic,)
            if age > no_update_period_before_page:
                message = '%s: CRITICAL: last update %s' \
                          % (mnemonic, time.strftime('%m/%d/%y %H:%M:%S',
                                                     time.gmtime(last_update)))
                return_value = CRITICAL
            elif age > no_update_period_before_warn:
                message = '%s: WARNING: last update %s' \
                          % (mnemonic, time.strftime('%m/%d/%y %H:%M:%S',
                                                     time.gmtime(last_update)))
                return_value = WARNING

            if return_value != CRITICAL:
                if update_failures > consecutive_failures_before_page:
                    message = '%s: CRITICAL: %s consecutive failures.\n' % \
                              (mnemonic, update_failures)
                    message += '  Last exception: %s' % (last_exception)
                    return_value = CRITICAL
                elif update_failures > consecutive_failures_before_warn:
                    message = '%s: WARNING: %s consecutive failures\n' % \
                              (mnemonic, update_failures)
                    message += '  Last exception: %s' % (last_exception)
                    return_value = WARNING

        self.print_verbose('%s: Status: %s' % (mnemonic, return_value))
        return return_value, message


    def get_return_value(self):
        """
        Computes the value and message to be returned/printed by FeedsMonitor
        """
        query = """
        SELECT mnemonic
        FROM   sources
        """
        mnemonics = self.run_query(query)
        mnemonics = [tup[0] for tup in mnemonics]

        if self.feed:
            if self.feed in mnemonics:
                return_value, message = self.get_feed_status(self.feed)
            else:
                error_msg = '%s: not found in the database' % (self.feed,)
                raise FeedsMonitorError(error_msg)
        else:
            if mnemonics:
                return_value = OK
                ok_count = 0
                warning_count = 0
                critical_count = 0
                for mnemonic in mnemonics:
                    feed_status, msg = self.get_feed_status(mnemonic)
                    if feed_status == OK:
                        ok_count += 1
                    elif feed_status == WARNING:
                        if return_value != CRITICAL:
                            feed_status = WARNING
                        warning_count += 1
                    else:
                        return_value = CRITICAL
                        critical_count += 1
                        if not self.opts.cacti:
                            print msg
                message = 'success:%s warning:%s critical:%s' % \
                          (ok_count, warning_count, critical_count)
            else:
                raise FeedsMonitorError('Database has no feeds to monitor')

        return return_value, message


    def run(self):
        try:
            self.parse_args()

            self.setup_db_conn()

            current_value, message = self.get_return_value()

            if self.opts.cacti:
                print message
            else:
                if self.feed:
                    print '%s - %s' % (current_value, message)
                else:
                    print message
                self.retval = current_value

        except FeedsMonitorHelpException:
            self.retval = UNKNOWN
        except FeedsMonitorError, e:
            if self.opts.cacti:
                print '0'
            else:
                print e
            self.retval = UNKNOWN
        return self.retval


if __name__  == '__main__':
    feeds_monitor = FeedsMonitor()
    retval = feeds_monitor.run()
    sys.exit(retval)
