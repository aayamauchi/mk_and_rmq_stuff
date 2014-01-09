#!/usr/bin/python26
import types


class NoViolations(Exception):
    pass


def convert_unicode_to_string(obj):
    """If the given object is a unicode object, return the string version
    of it, if it is any other sort of object return the object."""
    if type(obj) is types.UnicodeType:
        return str(obj)
    else:
        return obj


def convert_unicode_items_to_strings(unicode_dict):
    """Takes a dictionary and converts any unicode keys or values to their
    string equivalents."""
    new_dict = dict()
    for key, value in unicode_dict.iteritems():
        new_key = convert_unicode_to_string(key)
        if type(value) is types.DictType:
            new_value = convert_unicode_items_to_strings(value)
        elif type(value) is types.ListType:
            new_value = [convert_unicode_to_string(x) for x in value]
        else:
            new_value = convert_unicode_to_string(value)
        new_dict[new_key] = new_value
    return new_dict


def getcode(addinfourl):
    """Get HTTP return code in a python library version independent way"""
    if hasattr(addinfourl, 'code'):
        return addinfourl.code
    return addinfourl.getcode()


if __name__ == '__main__':
    import cmdline
    import os.path
    import sys
    import urllib2
    import simplejson
    import time

    # For easier testing of this script with local json file
    if os.path.exists(sys.argv[1]):
        sla_violations = simplejson.load(open(sys.argv[1], "rb"))
    else:
        required_args = ('host',)
        option_manager = cmdline.OptionManager(required_args=required_args)
        option_manager.add_option('-p', '--port', dest='port', default=8080,
                type="int", help="The port to connect to.  Default: %default")
        try:
            option_manager.parse_options()
        except cmdline.MissingRequiredArgument, e:
            sys.stderr.write("Missing required argument %s.\n" % (e.argument,))
            option_manager.print_help()
            sys.exit(3)

        options = option_manager.options
        host = option_manager.args['host']

        url = "http://%s:%d/sla_violations" % (host, options.port)
        req = urllib2.Request(url)
        try:
            http_connection = urllib2.urlopen(url)
            code = getcode(http_connection)
            if code >= 400:
                print "CRITICAL - Problem accessing SLA URL %s . " \
                    "Server returned HTTP CODE %d ." % (url, code)
                sys.exit(2)
        except Exception, e:
            print "CRITICAL - Problem accessing SLA URL %s : %s" % (url, e)
            sys.exit(2)
        sla_violations = simplejson.load(http_connection)

    try:
        n = len(sla_violations)
        if n == 0:
            raise NoViolations
    except (TypeError, NoViolations):
        # No sla_violations, we're all good
        print "OK - All applications are meeting their SLAs."
        sys.exit(0)

    now = int(time.time())
    violations_data = list()
    for violation in sla_violations.items():
        violation = violation[1]
        try:
            last_update = int(violation.get("age"))
        except:
            # In case we somehow encounter the age = "" bug again
            sys.stderr.write("The age data for SLA violation is empty")
            sys.exit(3)
        component = violation.get("comp")
        environment = violation.get("env")
        contact = violation.get("contact")
        sla = int(violation.get("sla"))
        violations_data.append((component, environment, last_update, contact, sla))

    error_message = "CRITICAL - %d application sla violations (see below for " \
            "details):" % (len(violations_data),)
    for violation in violations_data:
        error_message += " %s/%s last updated %s seconds ago." \
                " Contact: %s. SLA: %d seconds.," % violation
    error_message = error_message.rstrip(',')

    print error_message
    sys.exit(2)
