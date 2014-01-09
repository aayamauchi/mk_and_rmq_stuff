#!/usr/bin/env python26

# -*- coding: ascii -*-

# Reads in nagios config, dumps out escalation that nagios is using.
# Mike Lindsey (mlindsey@ironport.com) 12/9/2009


import base64
import os
import socket
import sys
import traceback
import time
import re
import pprint

from optparse import OptionParser


def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    parser = OptionParser()
    parser.add_option("-H", "--Host", type="string", dest="host",
                            help="hostname")
    parser.add_option("-S", "--Service", type="string", dest="service",
                            help="service")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    parser.add_option("-o", "--objects", type="string", help="objects.cache file",
                            default="/usr/local/nagios/var/objects.cache")
    (options, args) = parser.parse_args()
    exitflag = 0
    if not options.host:
        exitflag = exitflag + 1
        print "Need host"
    if exitflag > 0:
        parser.print_help()
        sys.exit(0)
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

    return options

def process_object(file):
    """Read object file, sanitize and store in global variable."""
    object = {}
    try:
        object_lines = open(file).readlines()
    except:
        print("Tried to open escalation file - fail")
    else:
        tag = ''
        last = ''
        for line in object_lines:
            line = line.rstrip().lstrip()
            if not line:
                continue
            # Comments.  Possibly print, definitely ignore.
            if line.startswith('#'):
                if options.verbose and last != 'comment':
                    print("Read comment from object file.")
                    last = 'comment'
                if options.verbose:
                    print(line, False)
                continue
            last = ''
            # Here there be data!
            if line.startswith('define'):
                temp = {}
                old_tag = tag
                tag = line.split()[1]
                if tag.endswith('status'):
                    tag = tag.split('status')[0]
                if tag != old_tag:
                    if options.verbose:
                        if old_tag:
                            print("Finished loading %s '%s' items - ok" % (tag_count, old_tag))
                        print("Beginning define block for '%s'" % (tag))
                    tag_count = 1
                else:
                    tag_count += 1
                if not object.has_key(tag):
                    object[tag] = {}
                continue
            # Here ends data!
            if line.endswith('}'):
                if line != '}':
                    (entry, value) = line.split(None, 1)
                    try:
                        value = float(value)
                    except:
                        value = value.strip()
                    temp[entry] = value
                if tag.endswith('escalation'):
                    # handle host and service escalations here. 
                    # append to object as a list.
                    try:
                        host_name = temp.pop('host_name')
                    except:
                        host_name = temp.pop('hostgroup_name')
                    if temp.has_key('service_description'):
                        service = temp.pop('service_description')
                    else:
                        service = None
                    if not object[tag].has_key(host_name):
                        if service is not None:
                            object[tag][host_name] = {}
                        else:
                            object[tag][host_name] = []
                    if service:
                        if not object[tag][host_name].has_key(service):
                            object[tag][host_name][service] = []
                    if service and temp not in object[tag][host_name][service]:
                        try:
                            object[tag][host_name][service].append(temp)
                        except:
                            print tag, host_name, service, temp
                            pprint.pprint(object[tag][host_name].keys())
                            sys.exit(2)
                    elif not service and temp not in object[tag][host_name]:
                        try:
                            object[tag][host_name].append(temp)
                        except:
                            print tag, host_name, temp
                            pprint.pprint(object[tag][host_name].keys())
                            sys.exit(2)
                    elif options.verbose:
                        print("Found potentially duplicate object, skipping.")
                    if options.verbose:
                        if service is None:
                            print("%s '%s' loaded - ok" % (tag, host_name))
                        else:
                            print("%s '%s/%s' loaded - ok" % (tag, host_name, service))
                elif temp.has_key('%s_name' % (tag)):
                    # Catchall for anything with *_name
                    tag_name = temp.pop('%s_name' % (tag))
                    object[tag][tag_name] = temp
                    if options.verbose:
                        print("%s '%s' loaded - ok" % (tag, tag_name))
                elif temp.has_key('service_description'):
                    # Services 
                    if not temp.has_key('host_name'):
                        temp['host_name'] = None
                    host_name = temp.pop('host_name')
                    if not object[tag].has_key(host_name):
                        object[tag][host_name] = {}
                    service = temp.pop('service_description')
                    object[tag][host_name][service] = \
                            temp
                    if options.verbose:
                        print("%s '%s/%s' loaded - ok" % (tag, host_name, service))
                elif not service and temp not in object[tag][host_name]:
                    object[tag][host_name].append(temp)
                elif tag in ['hostdependency', 'servicedependency', 'hostescalation', 'serviceescalation']:
                    continue
                else:
                    print("unhandled tag %s - fail" % (tag))
                    print(pprint.pprint(temp))
            elif line:
                try:
                    (entry, value) = line.split(None, 1)
                except:
                    entry = line
                    value = ''
                try:
                    value = float(value)
                except:
                    value = value.strip()
                temp[entry] = value
    if options.verbose:
        print("Finished loading %s '%s' items - ok" % (tag_count, old_tag))

    return object

def get_hostgroups_by_host(objects, host=None):
    """Pass a hostname, or None, and get that host's hostgroups or
    ALL hostgroups."""
    hostgroups = set()
    for group in objects['hostgroup'].keys():
        if host is not None:
            if host in objects['hostgroup'][group]['members']:
                hostgroups.add(group)
        else:
            hostgroups.add(group)
    if host is not None and objects['host'][host].has_key('hostgroups'):
        for group in objects['host'][host]['hostgroups'].split(','):
            hostgroups.add(group)
    
    return hostgroups

def get_escalations():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.service:
        key = 'serviceescalation'
    else:
        key = 'hostescalation'

    objects = process_object(options.objects)
    hostgroups = get_hostgroups_by_host(objects, options.host)
    escalations = objects[key]
    hosts = hostgroups.union([options.host, '*'])
    items = []
    if hosts.intersection(escalations.keys()):
        for key in hosts:
            if key not in escalations.keys():
                continue

            if options.service:
                if escalations[key].has_key(options.service):
                    for item in escalations[key][options.service]:
                        contacts = []
                        if item.has_key('contacts'):
                            contacts.append(item['contacts'])
                        if item.has_key('contact_groups'):
                            contacts.append(item['contact_groups'])
                        items.append('%i-%i @ %im in %s to %s' % (item['first_notification'],
                                item['last_notification'], item['notification_interval'],
                                item['escalation_period'], ','.join(contacts)))
            elif not options.service:
                for item in escalations[key]:
                    contacts = []
                    if item.has_key('contacts'):
                        contacts.append(item['contacts'])
                    if item.has_key('contact_groups'):
                        contacts.append(item['contact_groups'])
                    items.append('%i-%i @ %im in %s to %s' % (item['first_notification'],
                            item['last_notification'], item['notification_interval'],
                            item['escalation_period'], ','.join(contacts)))

    for item in items:
        print item

    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return 


options = init()

get_escalations()

