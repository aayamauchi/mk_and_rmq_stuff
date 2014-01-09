#!/usr/bin/python26

# :Author: vburenin
# :Version: $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/kelvin_monitor.py#1 $

import MySQLdb
import optparse
import os
import re
import sys
import time

# required for slicing time-based thresholds from nagios macros
import datetime

from MySQLdb.constants import CR, ER

# AVAILABLE FEATURES.
ARS = 'ars'
PHLOG = 'phlog'
CASEPKGS = 'casepkgs'
CLEANER = 'cleaner'
MODULES = [ARS, PHLOG, CASEPKGS, CLEANER]

# EXIT CODES.
UNKNOWN = 3
CRITICAL = 2
WARNING = 1
OK = 0

class KelvinMonitor:

    """Kelvin Monitoring class"""

    def __init__(self, host, db, user, passwd):
        self._host = host
        self._user = user
        self._db = db
        self._passwd = passwd

    def __execute_query(self, query):
        """Simple method to handle/retry some possible errors"""
        attempts = 3
        while attempts > 0:
            try:
                conn = MySQLdb.connect(host=self._host,
                                       user=self._user,
                                       passwd=self._passwd,
                                       db=self._db)
                cursor = conn.cursor()
                cursor.execute(query)
                data = cursor.fetchone()
                cursor.close()
                conn.close()
                if data is None:
                    return -1
                return data[0]

            except MySQLdb.OperationalError, e:
                if e.args[0] in (CR.CONNECTION_ERROR,
                                 CR.UNKNOWN_HOST,
                                 ER.ACCESS_DENIED_ERROR,
                                 ER.BAD_DB_ERROR):
                    print e.args[1]
                    sys.exit(CRITICAL)
                raise
            except Exception:
                attempts -= 1
                raise

        return None

    def check_time(self, feature, warn_val, crit_val):
        """Check last data update.

        :param feature: the feature name
        :parama warn_val: warning value
        :parama crit_val: critical value
        :return: tuple of exit code and text message
        """

        if feature == ARS:
            query = """SELECT ars_data_ver FROM ars_data
                       ORDER BY ars_data_ver DESC LIMIT 1"""

        if feature == PHLOG:
            query = """SELECT unixtime FROM sbnp_ipas_hits
                       ORDER BY unixtime DESC LIMIT 1"""

        if feature == CASEPKGS:
            query = """SELECT pkg_ver FROM ipas_rules
                       ORDER BY pkg_ver DESC LIMIT 1"""

        result = self.__execute_query(query)
        if result is None:
            return (UNKNOWN, 'DB Error has happened!')
        if result < 0:
            return (CRITICAL, 'No data were fetched from the DB!')

        rtime = int(time.time() - result)

        if (rtime > crit_val):
            return (CRITICAL, 'Data lag is too high: %d' % (rtime,))

        if (rtime > warn_val):
            return (WARNING, 'Data lag is high: %d' % (rtime,))

        return (OK, str(rtime))

    def check_cleaner_back(self, table_name, warn_val, crit_val):
        """Check that partitions were deleted.

        :param table_name: table name to check
        :param warn_val: warning value
        :param crit_val: critical value
        :return: tuple of exit code and text message
        """

        query = """SELECT partition_name
                   FROM INFORMATION_SCHEMA.partitions
                   WHERE table_name = '""" + table_name + """'
                   AND table_schema = DATABASE()
                   AND partition_name LIKE 'p%'
                   ORDER BY partition_name ASC LIMIT 1"""

        result = self.__execute_query(query)
        if result is None:
            return (UNKNOWN, 'DB Error has happened!')
        if result == -1:
            return (CRITICAL, 'No data were fetched from the DB!')

        if not re.match(r'^\d+$', result[1:]):
            return (CRITICAL, 'Incorrect partition name detected!')

        rtime = int(time.time() - int(result[1:])) / 86400
        if (rtime > crit_val):
            return (CRITICAL, 'Partition %s.%s is older than we need!' % \
                              (table_name, result))

        if (rtime > warn_val):
            return (WARNING, 'Partition %s.%s is older than we need!' % \
                             (table_name, result))
        return (OK, str(rtime))

    def check_cleaner_forward(self, table_name, warn_val, crit_val):
        """Check that partitions were created.

        :param table_name: table name to check
        :param warn_val: warning value
        :param crit_val: critical value
        :return: tuple of exit code and text message
        """

        query = """SELECT partition_name
                   FROM INFORMATION_SCHEMA.partitions
                   WHERE table_name = '""" + table_name + """'
                   AND table_schema = DATABASE()
                   AND partition_name LIKE 'p%'
                   ORDER BY partition_name DESC LIMIT 1"""

        result = self.__execute_query(query)
        if result is None:
            return (UNKNOWN, 'DB Error has happened!')
        if result == -1:
            return (CRITICAL, 'No data were fetched from the DB!')

        if not re.match(r'^\d+$', result[1:]):
            return (CRITICAL, 'Incorrect partition name detected!')

        rtime = int(int(result[1:]) - time.time()) / 86400

        if (rtime < crit_val):
            return (CRITICAL, 'Not enough new partitions are created for %s!' % \
                              (table_name,))

        if (rtime < warn_val):
            return (WARNING, 'A few new partitions are created for %s!' % \
                             (table_name,))
        return (OK, str(rtime + 1))


def init_option_parser():
    """Options parser initializator"""
    usage_text = 'usage: %s OPTIONS' % (os.path.basename(sys.argv[0]),)
    option_parser = optparse.OptionParser(usage=usage_text)

    option_parser.add_option('-c', '--critical', metavar='SECONDS',
                           action='store', dest='critical', default=None,
                           help='The warning value')

    option_parser.add_option('-w', '--warning', metavar='SECONDS',
                           action='store', dest='warning', default=None,
                           help='The critical value')

    option_parser.add_option('-H', '--dbhost', metavar='DBHOST',
                           action='store', type='string',
                           dest='host', default=None,
                           help='The DB hostname')

    option_parser.add_option('-d', '--dbname', metavar='DBNAME',
                           action='store', type='string',
                           dest='dbname',
                           help='The DB name')

    option_parser.add_option('-u', '--user', metavar='DBUSER',
                           action='store', type='string',
                           dest='user',
                           help='The DB username')

    option_parser.add_option('-p', '--password', metavar='PASSWORD',
                           action='store', type='string',
                           dest='passwd',
                           help='DB user passwords')

    option_parser.add_option('-f', '--feature', metavar='FEATURENAME',
                           action='store', type='string',
                           dest='feature',
                           help='The feature name: cleaner/casepkgs/ars/phlog')

    option_parser.add_option('-t', '--table', metavar='TABLENAME',
                           action='store', type='string',
                           dest='table', default=None,
                           help='Only usable with CLEANER module')

    try:
        (opt, args) = option_parser.parse_args()
    except optparse.OptParseError, err:
        print err
        sys.exit(2)

    # check for magic _WARN and _CRIT macros
    dt = datetime.datetime.now()
    weekday = dt.weekday()
    hour = dt.timetuple()[3]
    try:
        opt.critical = int(opt.critical)
    except ValueError:
        try:
            opt.critical = int(opt.critical.split()[(weekday*24)+hour])
        except:
            opt.critical = 'UNDEF'
            
    try:
        opt.warning = int(opt.warning)
    except ValueError:
        try:
            opt.warning = opt.warning.split()[(weekday*24)+hour]
        except:
            opt.warning = 'UNDEF'

    try:
        opt.critical = int(opt.critical)
        opt.warning = int(opt.warning)
    except ValueError:
        print "-c, --critical must be either an integer, or $_SERVICECRIT$; not: %s" % (opt.critical)
        print "-w, --warning must be either an integer, or $_SERVICEWARN$; not: %s" % (opt.warning)
        option_parser.print_help()
        sys.exit(1)

    return option_parser, opt, args


def main():
    """Entry point"""

    op, opts, args = init_option_parser()

    if opts.table and opts.feature != CLEANER:
        print 'The table name must be specified for Cleaner only'
        op.print_help()
        sys.exit(UNKNOWN)

    if not (opts.host and opts.dbname and opts.user and opts.passwd and
            (opts.warning is not None) and (opts.critical is not None) and
            opts.feature):
        print 'At least these options must be specified:'
        print 'DB host, DB name, User name, Password, Feature,'
        print 'Critical value, Warning Value'
        op.print_help()
        sys.exit(UNKNOWN)

    if opts.feature not in MODULES:
        print 'Unknown feature name is specified'
        op.print_help()
        sys.exit(UNKNOWN)

    if not opts.table and opts.feature == CLEANER:
        print 'The table name must be specified for Cleaner'
        op.print_help()
        sys.exit(UNKNOWN)

    km = KelvinMonitor(opts.host, opts.dbname, opts.user, opts.passwd)
    if opts.feature == CLEANER:
        code, msg = km.check_cleaner_back(opts.table, opts.warning,
                                          opts.critical)
        if code == 0:

            # Here is hardcoded values that we should be as it specified
            # we should make sure that we have enough partitions that
            # created for the future data.

            code, msg = km.check_cleaner_forward(opts.table, 6, 4)
        print msg
        sys.exit(code)
    else:
        code, msg = km.check_time(opts.feature, opts.warning, opts.critical)
        print msg
        sys.exit(code)


if __name__ == '__main__':
    main()
