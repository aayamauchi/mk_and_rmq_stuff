#! /usr/bin/python26

"""Corpus monitoring script which adheres to the sysops monitor guidelines:
http://awesome.ironport.com/twiki/bin/view/Main/MonitoringPlugin

This script monitors the corpus_web.statistics table, and alerts/warns on
minimum thresholds.  For usage type:

python26 corpus_stats_monitor.py -h

author: bjung
"""

import cPickle
import MySQLdb
import optparse
import sys
import time

# valid return values
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3


class BaseMonitorError(Exception):
    pass


class BaseMonitorHelpException(Exception):
    pass


class BaseMonitor(object):

    def __init__(self):
        """Constructor for the monitor class, sub-classes will likely
        override this method to add additional options, e.g:

        def __init__(self):
            super(SubClass, self).__init__()
            self.option_parser.add_option(...)
        """
        self.usage = """usage: %prog [options] args"""
        self.option_parser = optparse.OptionParser(self.usage)
        self.option_parser.add_option(
            '-H', '--host', dest='host',
            help='[required] database host name.')
        self.option_parser.add_option(
            '-u', '--user', dest='user',
            help='[required] database read-only user.')
        self.option_parser.add_option(
            '-p', '--password', dest='password',
            help='[required] database read-only password.')
        self.option_parser.add_option(
            '-d', '--database', dest='database',
            help='[required] database name.')
        self.option_parser.add_option(
            '-v', '--verbose', dest='verbose', action='store_true', default=False,
            help='verbose (debug) output')
        self.option_parser.add_option(
            '-C', '--cacti', dest='cacti', action='store_true', default=False,
            help='cacti compatible output (incompatible with verbose flag)')
        self.option_parser.add_option(
            '-w', '--warning', dest='warning',
            help='warning threshold value (incompatible with cacti flag).')
        self.option_parser.add_option(
            '-c', '--critical', dest='critical',
            help='critical threshold value (incompatible with cacti flag).')
        self.option_parser.add_option(
            '-m', '--min', dest='min', action='store_true', default=False,
            help='consider threshold as minimum allowable value')
        self.opts = None
        self.args = None
        self.retval = OK
        self.db_connection = None

    def print_verbose(self, string):
        """Print only if verbose flag is set
        """
        if self.opts.verbose:
            print '[dbg] ' + string

    def print_std(self, string):
        """Print only if the cacti option is not set
        """
        if not self.opts.cacti:
            print string

    def check_option_conflicts(self):
        """Check for any conficting options, and handle appropriately
        """
        err_strings = []
        if not (self.opts.host and self.opts.user \
                and self.opts.password and self.opts.database):
            err_strings.append(
                'options --host, --user, --password, and --database are required')
        if self.opts.verbose and self.opts.cacti:
            err_strings.append(
                'options --cacti and --verbose are mutually exclusive')
        if self.opts.warning and self.opts.cacti:
            err_strings.append(
                'options --cacti and --warning are mutually exclusive')
        if self.opts.critical and self.opts.cacti:
            err_strings.append(
                'options --cacti and --critical are mutually exclusive')
        if err_strings:
            self.option_parser.error('\n'.join(err_strings))

    def parse_args(self):
        """Parse the command line.  Raise appropriate exceptions for invalid
        input.
        """
        try:
            (self.opts, self.args) = self.option_parser.parse_args()
            self.check_option_conflicts()
        except SystemExit:
            raise BaseMonitorHelpException
        except Exception, e:
            print e
            if not self.opts.cacti:
                self.option_parser.print_help()
            raise BaseMonitorError(
                'ERROR parsing arguments')

    def print_warning(self, value):
        print 'WARNING - Current value: %s. Warning threshold %s.' % (
            value, self.opts.warning)
        self.retval = WARNING

    def print_critical(self, value):
        print 'CRITICAL - Current value: %s. Critical threshold %s.' % (
            value, self.opts.critical)
        self.retval = CRITICAL

    def print_ok(self, value):
        print 'OK - Current value: %s.' % (value,)
        self.retval = OK

    def setup_db_conn(self):
        """Initialize the db_connection.
        """
        try:
            self.db_connection = MySQLdb.connect(
                user=self.opts.user,
                passwd=self.opts.password,
                host=self.opts.host,
                db=self.opts.database)
        except MySQLdb.Error, e:
            raise BaseMonitorError(
                'ERROR opening database connection: %s' % (e,))

    def get_current_value(self):
        """Get the value which should be checked agains the threshold.  This
        is the main logic of the monitor, and must be over-ridden with the
        specific logic required.  This is generally a database query.
        """
        raise NotImplementedError

    def comparison(self, current_value, threshold_value):
        """Defines how the gotten current value is compared against the
        set threshold
        """
        if self.opts.min:
            comp = float(current_value) > float(threshold_value)
        else:
            comp = float(current_value) < float(threshold_value)
        return comp

    def run(self):
        try:
            self.parse_args()
            self.setup_db_conn()
            now = time.time()
            current_value = self.get_current_value()
            diff = time.time() - now
            self.print_verbose('query took %f seconds' % (diff,))
            if self.opts.cacti:
                print current_value
            else:
                err = OK
                if self.opts.warning and \
                    self.comparison(current_value, self.opts.warning):
                    err = WARNING
                if self.opts.critical and \
                    self.comparison(current_value, self.opts.critical):
                    err = CRITICAL
                if err == CRITICAL:
                    self.print_critical(current_value)
                elif err == WARNING:
                    self.print_warning(current_value)
                else:
                    self.print_ok(current_value)
        except BaseMonitorHelpException:
            self.retval = UNKNOWN
        except BaseMonitorError, e:
            if self.opts.cacti:
                print '0'
            else:
                print e
            self.retval = UNKNOWN
        return self.retval

# End base class.  Specific monitor class should be implemented below

class CorpusStatsMonitor(BaseMonitor):
    """Queries the corpus_web.statistics table to get metrics for the rates
    of different sources.  This includes the rate of messages coming from
    traps (spamcop), senderbase (goodlists), in addition to rates of messages
    getting to the pre and post processors.  This data is inherently at least
    one hour old due to the method in which it is collected."""

    def __init__(self):
        super(CorpusStatsMonitor, self).__init__()
        self.option_parser.add_option(
        '-S', '--source', dest='source', default='trap',
        help='valid values for source include ' + \
             '[trap|goodlist|preprocessor|postprocessor]')

    def get_current_value(self):
        if self.opts.source == 'trap':
            count_type = 'corpus_spamtrap_pre_deliver_count_last_24'
        elif self.opts.source == 'goodlist':
            count_type = 'h_sendbase_com_deliver_count_last_24'
        elif self.opts.source == 'preprocessor':
            count_type = 'corpus_pre_deliver_count_last_24'
        elif self.opts.source == 'postprocessor':
            count_type = 'corpus_post_deliver_count_last_24'
        else:
            raise BaseMonitorError('unknown source %s' % (self.opts.source,))
        cursor = self.db_connection.cursor()
        query = """SELECT value_name, value
                   FROM statistics s
                   WHERE s.value_name LIKE '%%last_24'"""
        self.print_verbose('executing query: %s' % (query,))
        try:
            cursor.execute(query)
        except MySQLdb.Error, e:
            raise BaseMonitorError('ERROR running query: %s' % (e,))
        last_24 = cursor.fetchall()
        last_24_unpacked = dict()
        for name, data in last_24:
            data_dict = cPickle.loads(data)
            if name not in last_24_unpacked:
                last_24_unpacked[name] = dict()
            for hour, count in data_dict.iteritems():
                baseline = int(time.time()) - (24 * 3600)
                if hour < baseline:
                    continue
                hour = ((hour - baseline) / 3600) - 23
                last_24_unpacked[name][hour] = \
                    last_24_unpacked[name].get(hour, 0) + count
        return last_24_unpacked[count_type][-1]

def main():
    csm = CorpusStatsMonitor()
    retval = csm.run()
    sys.exit(retval)

if __name__ == '__main__':
    main()

