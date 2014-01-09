
"""
WBRS Nagios plugin common routines

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/wbrs_nagios_plugins.py#1 $

:Author: nfriess, moorthi
"""

import optparse
import sys

RESULT_OK=0
RESULT_WARNING=1
RESULT_CRITICAL=2
RESULT_SCRIPT_ERROR=3

STATUS_NAMES = ('OK', 'Warning', 'Critical', 'Unknown')

class UsageError(Exception):
    pass

class NagiosOptionParser(optparse.OptionParser):
    """
    The standard OptionParser error behavior is to exit(2).  The exit status of
    2 is already used by a standard nagios plugin, so we need to trap the error
    and handle it separately.
    """
    def error(self, msg):
        raise UsageError(msg)

def exitwith(result, msg):
    print '%s: %s' % (STATUS_NAMES[result], msg)
    sys.exit(result)

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with command-line arguments,
    and return it.
    """
    optp = NagiosOptionParser()

    optp.add_option('-d', '--db-server', dest='db_server', action='store',
            type='string', help='db-server to check status on')
    optp.add_option('-v', '--verbosity', dest='verbosity',
            action='store', type='int', help='Verbosity: 0-2')
    optp.add_option('-D', '--db-name', dest='db_name',
            action='store', type='string', help='db-name to read from')
    optp.add_option('-w', '--warn-threshold', dest='warn_threshold',
            action='store', type='int')
    optp.add_option('-c', '--critical-threshold', dest='critical_threshold',
            action='store', type='int')
    optp.add_option('--db-user', dest='db_user', action='store', type='string',
            help='User for db connection')
    optp.add_option('--db-passwd', dest='db_passwd', action='store',
            type='string', help='Passwd for db connection')

    optp.set_defaults(verbosity=0)
    return optp

def process_args(optp):
    """
    Given an option parser, optp, execute it and check options for consistency.

    :return: opt, args
    """
    (opt, args) = optp.parse_args()

    if not opt.db_server:
        raise UsageError('db-server is required')

    if opt.verbosity not in (0, 1, 2):
        raise UsageError('Verbosity must be 0, 1, or 2')

    if not opt.db_name:
        raise UsageError('db_name is required')

    if opt.warn_threshold < 1:
        raise UsageError('warn_threshold must be an integer greater than 0')

    if opt.critical_threshold < opt.warn_threshold:
        raise UsageError('critical_threshold must be greater than warn_threshold (%d)' %
                (opt.warn_threshold,))

    return opt, args

class InvalidDBSchema(Exception):
    pass

def check_db_schema(conn, table, required_columns):
    try:
        cursor = conn.cursor()
        cursor.execute('DESCRIBE %s' % (table,))
        raw_fields = cursor.fetchall()
        fields_dict = dict([(entry[0], entry[1:]) for entry in raw_fields])
        missing = filter(lambda x: not fields_dict.has_key(x), required_columns)
        if missing: 
            raise InvalidDBSchema("Invalid db schema. %s missing fields: %s" %
                                  (table, ','.join(missing)))
    finally:
        cursor.close()

