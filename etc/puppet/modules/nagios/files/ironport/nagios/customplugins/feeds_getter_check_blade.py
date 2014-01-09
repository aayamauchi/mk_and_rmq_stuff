#!/usr/bin/python26
"""
Feeds-getter Nagios plugin.

For more information:
http://eng.ironport.com/docs/is/web_reputation/1_2/eng/ER3/nagios-plugins.rst#feeds-getter-monitor

$Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/feeds_getter_check_blade.py#1 $

:Author: moorthi
"""

import sys
import traceback
import MySQLdb

from optparse import OptionGroup

import base_nagios_plugin as nagios_plugins

DEFAULT_WARN_THRESHOLD     = 2
DEFAULT_CRITICAL_THRESHOLD = 4

def make_option_parser():
    """
    Build a NagiosOptionParser, populate it with arguments for checking the
    feeds getter, and return it.
    """
    optp = nagios_plugins.make_option_parser()

    opt_warn = optp.get_option('-w')
    opt_warn.help = 'Multiple of refresh_interval for warning. ' + \
                    'Default: %d' % DEFAULT_WARN_THRESHOLD

    opt_crit = optp.get_option('-c')
    opt_crit.help = 'Multiple of refresh_interval for a critical error. ' + \
                    'Default: %d' % DEFAULT_CRITICAL_THRESHOLD

    manual_check_group = OptionGroup(optp, 'Manual check options',
                                     'Use these options for checking status on '
                                     'particular feeds.')

    manual_check_group.add_option('-f', '--feed', dest='feed', action='store',
                                  type='string', metavar='MNEMONIC', 
                                  help='feed mnemonic to check status on')
    manual_check_group.add_option('-r', '--refresh-interval',
                                  dest='static_refresh_interval',
                                  metavar='SECONDS', type='int',
                                  help='a static threshold for particular feed '
                                  '(omits feed\'s refresh_interval value)')
    optp.add_option_group(manual_check_group)

    optp.set_defaults(db_name='wbrs_feeds',
                      warn_threshold=DEFAULT_WARN_THRESHOLD,
                      critical_threshold=DEFAULT_CRITICAL_THRESHOLD)

    return optp


def build_rule_data(crit_mult, warn_mult, rules_list, static_refresh_interval):
    results = { 
        nagios_plugins.RESULT_OK: [], 
        nagios_plugins.RESULT_WARNING: [],
        nagios_plugins.RESULT_CRITICAL: [],
    }
    max_result = nagios_plugins.RESULT_OK

    for mnemonic, last_refresh, refresh_interval, now in rules_list:
        if static_refresh_interval is not None:
            refresh_interval = static_refresh_interval
        age = now - last_refresh
        max_ages = {
            nagios_plugins.RESULT_OK: 0, # Unused
            nagios_plugins.RESULT_WARNING: warn_mult * refresh_interval,
            nagios_plugins.RESULT_CRITICAL: crit_mult * refresh_interval,
        }

        status = nagios_plugins.RESULT_OK
        for level in (nagios_plugins.RESULT_WARNING, nagios_plugins.RESULT_CRITICAL):
            if age > max_ages[level]:
                status = level

        if refresh_interval == 0: # disabled rule.  don't warn.
            status = nagios_plugins.RESULT_OK

        if status > max_result: max_result = status

        rule_data = {
            'mnemonic': mnemonic,
            'last': str(last_refresh),
            'interval': str(refresh_interval),
            'age': str(age),
            'max_age': str(max_ages[status]),
            'cutoff': str(now - max_ages[status]),
            }

        results[status].append(rule_data)

    return max_result, results

def build_result_msg(verbosity, result, rule_data):
    """
    Build a result message based on the verbosity level
    """

    if result == nagios_plugins.RESULT_OK:
        return '%d feeds up to date' % len(rule_data[result])

    msgs = []
    for level in (nagios_plugins.RESULT_CRITICAL, nagios_plugins.RESULT_WARNING):
        msg = ''
        rules = rule_data[level]
        if len(rules) == 0:
            continue
        if level != result:
            msg += 'Past %s cutoff: ' % \
                    nagios_plugins.STATUS_NAMES[level]
        if verbosity < 2:
            entries = ['%(mnemonic)s:age=%(age)s:max=%(max_age)s' % \
                        rule for rule in rules]
            msg += ','.join(entries)
        elif verbosity == 2:
            tmpl ="'%(mnemonic)s' last=%(last)s int=%(interval)s cutoff=%(cutoff)s max_age=%(max_age)s age=%(age)s" 
            lines = [tmpl % rule for rule in rules]
            msg += '%d Feeds Beyond Max Age:\n' % (len(lines),) + '\n'.join(lines)
        else:
            assert(False, "Invalid verbosity")
        msgs.append(msg)
    return (verbosity == 2 and '\n' or ' ').join(msgs)

def check_feeds_getter_status(opt, args):
    rule_sql = """
SELECT mnemonic,
       last_refresh,
       refresh_interval,
       UNIX_TIMESTAMP(now())
FROM   feed_fetch_rules
"""

    static_refresh_interval = None
    if opt.feed:
        rule_sql += ' WHERE mnemonic="%s"' % opt.feed
        static_refresh_interval = opt.static_refresh_interval

    result = nagios_plugins.RESULT_SCRIPT_ERROR
    msg = "Script error"
    conn = MySQLdb.Connect(host=opt.db_server,
                           user=opt.db_user,
                           passwd=opt.db_passwd,
                           db=opt.db_name)

    try:
        nagios_plugins.check_db_schema(conn, 'feed_fetch_rules', 
                                       ('mnemonic', 'last_refresh', 'refresh_interval'))
    except nagios_plugins.InvalidDBSchema, e:
        msg = str(e)
        return result, msg

    try:
        cursor = conn.cursor()
        try:
            # Get all of the rule refresh information
            cursor.execute(rule_sql)
            rules = cursor.fetchall()
        finally:
            cursor.close()

        if len(rules) == 0:
            if opt.feed:
                msg = 'Invalid mnemonic %s' % opt.feed
            return result, msg

        result, rule_data = build_rule_data(opt.critical_threshold, 
                                            opt.warn_threshold, 
                                            rules,
                                            static_refresh_interval)

        msg = build_result_msg(opt.verbosity, result, rule_data)
        return result, msg

    finally:
        conn.close()

    return result, msg

def main():
    optp = make_option_parser()
    try:
        opt, args = nagios_plugins.process_args(optp)
    except nagios_plugins.UsageError, e:
        nagios_plugins.exitwith(nagios_plugins.RESULT_SCRIPT_ERROR, str(e))
        
    try:
        result, msg = check_feeds_getter_status(opt, args)
    except Exception, e:
        result = nagios_plugins.RESULT_SCRIPT_ERROR
        msg = "Exception: %s" % (str(e))
        if opt.verbosity > 1:
            msg += '\n' + traceback.format_exc()

    nagios_plugins.exitwith(result, msg)

if __name__ == '__main__':
    main()
