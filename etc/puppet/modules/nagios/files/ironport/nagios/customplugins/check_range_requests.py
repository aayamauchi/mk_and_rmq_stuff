#!/usr/bin/python26
#
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/check_range_requests.py#1 $
#

"""
Checks a website to make sure that it does not accept requests with the 
'Range' header.
"""


if __name__ == '__main__':
    import sys
    import urllib2

    try:
        url = sys.argv[1]
        request = urllib2.Request(url)
    except IndexError:
        print "syntax: %s <url>" % (sys.argv[0])
        sys.exit(2)


    request.add_header('Range', '80-90')

    try:
        page = urllib2.urlopen(request)
    except urllib2.HTTPError:
        return_code = sys.exc_info()[1].code
        if return_code == 403:
            print "OK - %s returned 403 for range requests." % (url)
            sys.exit(0)

        raise

    print "CRITICAL - url %s returned a 200 with a range request." % (url)
    sys.exit(2)
