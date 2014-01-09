#!/usr/bin/python26


if __name__ == '__main__':
    import simplejson
    import urllib2
    import urllib
    import types
    import optparse
    import sys
    import traceback
    import operator
    opt_parser = optparse.OptionParser()
    opt_parser.add_option('-r', '--resource',
            help="The resource record you want to query.  The resource " \
                 "record is '.' delimited.  The first two elements of " \
                 "the resource should be the product.module.")
    opt_parser.add_option('-w', '--warning', type="float",
            help="Set the warning threshold.")
    opt_parser.add_option('-c', '--critical', type="float",
            help="Set the critical threshold.")
    opt_parser.add_option('-H', '--host', 
            help="Set the host to query for values.")
    opt_parser.add_option('-p', '--port', default=9000,
            help="The port the server is running on.  Default: 9000")
    opt_parser.add_option('--gt', action="store_true",
            help="This tells the script to throw alerts when the value " \
                 "checked is greater than the threshold values supplied.")
    opt_parser.add_option("--lt", action="store_true",
            help="This tells the script to throw alerts when the value " \
                 "checked is greater than the threshold values supplied.")
    try:
        (options, args) = opt_parser.parse_args()
    except optparse.OptParseError:
        print "CRITICAL - Invalid commandline arguments."
        opt_parser.print_help()
        traceback.print_exc()
        sys.exit(2)

    if options.host == None:
        print "CRITICAL - Must specify a host with -H."
        opt_parser.print_help()
        sys.exit(2)

    resource_list = options.resource.split('/')

    url = "http://" + options.host + ":" + str(options.port) + "/"

    if options.resource[0] == "/":
        url = url + urllib.quote(options.resource[1:])
    else:
        url = url + urllib.quote(options.resource)

    if not options.critical == None or not options.warning == None:
        if (options.gt == None and options.lt == None) or \
                (options.gt == True and options.lt == True):
            print "CRITICAL - You must provide either --gt or --lt when " \
                  "specifying warning or critical thresholds."
            sys.exit(2)
        # using the script as a monitor.
        url = url + "?format=json&"

        operator_dict = {'greater': operator.gt,
                         'lesser': operator.lt}

        if options.gt == True: operator_func = "greater"
        if options.lt == True: operator_func = "lesser"

    url_data = urllib2.urlopen(url)

    if options.critical == None and options.warning == None:
        # Using the script to dump the raw json view.
        print ''.join(url_data.readlines())
        sys.exit(0)

    server = simplejson.load(url_data)[0]

    data = None
    # Recurse through the resource keys to get the final data
    for res in resource_list:
        if data == None:
            data = server[res]
        else:
            data = data[res]

    if type(data) == types.DictType:
        print "CRITICAL - Resource '%s' returned multiple values.  " \
                "Specify a more specific resource." % (options.resource)
        print "    Possible resources:"
        for key in data.keys():
            print "        %s/%s" % (options.resource, key)

        sys.exit(2)

    if type(data) == types.StringType:
        print "CRITICAL - Resource '%s' returned string value: %s." % \
                (options.resource, data)
        sys.exit(2)

    if not options.critical == None and \
           operator_dict[operator_func](data,options.critical):
        print "CRITICAL - Resource '%s' returned value (%s) %s " \
              "than threshold (%s)." % \
                (options.resource, str(data), operator_func, 
                 options.critical)
        sys.exit(2)

    if not options.warning == None and \
           operator_dict[operator_func](data,options.warning):
        print "WARNING - Resource '%s' returned value (%s) %s " \
                "than threshold (%s)." % \
                (options.resource, str(data), operator_func,
                 options.warning)
        sys.exit(1)

    print "OK - Resource '%s' returned %s." % (options.resource,
            str(data))
