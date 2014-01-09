#!/usr/bin/python26

# -*- coding: ascii -*-

# queries awesome to pull
# hostnames out and add new ones to cacti.
# Mike Lindsey (mlindsey@ironport.com) 7/10/2008


import base64
import os
import socket
import sys
import traceback
import time
import MySQLdb
import urllib
import simplejson
import pickle
import re

# fully qualified path to cacti home
cactihome = "/usr/share/cacti/"

from optparse import OptionParser

def funcname():
    # so we don't have to keep doing this over and over again.
    return sys._getframe(1).f_code.co_name

def init():
    # collect option information, display help text if needed, set up debugging
    parser = OptionParser()
    parser.add_option("-a", "--awesome", type="string", dest="awesome",
                            default="asdb.ironport.com",
                            help="awesome server")
    parser.add_option("-H", "--host", type="string", dest="host",
                            help="Sync a specific host")
    parser.add_option("-m", "--mysql", type="string", dest="mysql",
                            default="ops-cacti-db-m1.vega.ironport.com",
                            help="cacti mysql database host")
    parser.add_option("-s", "--skiphost", action="store_true", dest="skiphost",
                            default=False,
                            help="Skip host creation, just print what we would do.")
    parser.add_option("-c", "--community", type="string", dest="community",
                            default="y3ll0w!",
                            help="SNMP community string")
    parser.add_option("-l", "--location", type="string", dest="location",
                            help="Optional ASDB location limiter.")
    parser.add_option("-r", "--rolemaps", action="store_true", dest="rolemaps",
                            default=False,
                            help="Only sync rolemaps")
    parser.add_option("-C", "--cache", action="store_true", dest="cache",
                            default=False,
                            help="Use ASDB Cache from previous run.")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                            default=False,
                            help="print debug messages to stderr")
    (options, args) = parser.parse_args()
    if options.verbose: sys.stderr.write(">>DEBUG sys.argv[0] running in " +
                            "debug mode\n")
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return options

def init_cdb():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    conn = MySQLdb.connect (host = options.mysql,
                            user = "cactiuser",
                            passwd = "cact1pa55",
                            db = "cacti")
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return conn

def do_sql(sql):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() +
                            "()\n")
    conn = init_cdb()
    cursor = conn.cursor()
    if options.verbose: print "SQL: %s" % (sql)
    try:
        cursor.execute(sql)
    except:
        print "Error executing SQL '%s'" % (sql)
        sys.exit(0)
    results = cursor.fetchall()
    conn.commit()
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return results

def get_awesome_rolemaps():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() +
                            "()\n")
    print "Grabbing ASDB Rolemaps"
    cachefile = '/tmp/asdb_rolemaps.cache'
    hostlist = []
    if not options.cache:
        url="http://" + options.awesome + "/nagios/rolemap/data/?format=json"
        response=urllib.urlopen(url).read()
        hosts = simplejson.loads(response)
        cf = open(cachefile, 'w')
        pickle.dump(hosts, cf)
        cf.close()
    else:
        cf = open(cachefile)
        hosts = pickle.load(cf)

    for host in hosts:
        host['name'] = str(host['hostname'])
        host['profile'] = str(host['profile']['name'])
        location = str(host['hostname']).split('.')
        if len(location) > 1:
            host['location'] = location[1]
        else:
            host['location'] = 'UNKNOWN'
        try:
            hosttest = do_sql("SELECT hostname FROM host WHERE hostname='%s'" % (host['name']))[0]
        except:
            if options.verbose: print "Adding %s/%s to rolemap hostlist." % (host['name'], host['profile'])
            new = 1
        else:
            new = 0
        if set(products.keys()).intersection(host['hostgroups'].keys()):
            host['product'] = list(set(products.keys()).intersection(host['hostgroups'].keys()))[0]
            if host['hostgroups'].has_key('vip'):
                host['purpose'] = 'vip'
                host['discovery'] = 'ping'
            else:
                host['purpose'] = 'other'
                host['discovery'] = 'snmp'
            hostlist.append({'name': host['name'], 'template': host['profile'], 'graph': host['graph'],
                    'new': new, 'location': host['location'], 'product' : host['product'],
                    'purpose' : host['purpose'], 'discovery' : host['discovery'] })
        else:
            hostlist.append({'name': host['name'], 'template': host['profile'], 'graph': host['graph'],
                    'new': new, 'location': host['location']})

    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() +
                            "()\n")
    return(hostlist)

def get_cacti_hosts():
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    print "Grabbing Cacti host list"
    sql = "SELECT host.hostname, host_template.name FROM host, host_template WHERE "
    sql += "host.host_template_id = host_template.id"
    hosts = do_sql(sql)
    hostdict = {}
    for host in hosts:
        name = host[0]
        template = host[1]
        hostdict[name] = template
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return (hostdict)

def get_host_id(hostname):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    try:
        host_id = do_sql("SELECT id FROM host WHERE hostname='%s'" % (hostname))[0][0]
    except:
        print "Host id query failed for tree add for %s." % (hostname)
        host_id = None
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return host_id

def get_tree_id(tree):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    try:
        tree_id = do_sql("SELECT id FROM graph_tree WHERE name='%s'" % (tree))[0][0]
    except:
        os.popen("%s/cli/add_tree.php --type=tree --name='%s' --sort-method=natural --quiet" %
                (cactihome, tree)).readlines()
        try:
            tree_id = do_sql("SELECT id FROM graph_tree WHERE name='%s'" % (tree))[0][0]
        except:
            print "Graph tree %s not found, and create has failed." % (tree)
            sys.exit(0)
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return tree_id

def get_node_id(tree_id, node, depth=1):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    node_id = None
    try:
        output = os.popen("%s/cli/add_tree.php --list-nodes --tree-id=%s" % \
                (cactihome, tree_id)).readlines()
    except:
        print "Unable to run add_tree to get node list."
        sys.exit(0)
    for line in output:
        if not line.startswith('Header'): continue
        (id, header) = line.split('\t')[1:3]
        if header == node:
            node_id = id.strip('()')
            break
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return node_id

def add_node_to_tree(tree_id, parent_id, node):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    node_id = None
    if parent_id:
        parent_str = " --parent-node=%s " % (parent_id)
    else:
        parent_str = ""
    cmd = "%s/cli/add_tree.php --type=node --node-type=header --tree-id=%s %s --name='%s'" \
            % (cactihome, tree_id, parent_str, node)
    output = os.popen(cmd).readlines()
    if options.verbose: print cmd
    for line in output:
        if not line.startswith("Added"): continue
        node_id = line.split('(')[1].split(')')[0]
        break
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return node_id

def add_host_to_tree(tree, parent, node, host):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    tree_id = get_tree_id(tree)
    host_id = get_host_id(host)
    try:
        do_sql("SELECT id FROM graph_tree_items WHERE graph_tree_id=%s AND host_id=%s" % \
                (tree_id, host_id))[0][0]
    except:
        if options.verbose:
            print "Host %s being added to tree %s" % (host, tree)
    else:
        if options.verbose:
            print "Host %s already on tree %s" % (host, tree)
        return 
    if parent:
        #print "Parent node %s" % (parent)
        parent_id = get_node_id(tree_id, parent)
        #print "Parent node id %s" % (parent_id)
        if not parent_id:
            parent_id = add_node_to_tree(tree_id, None, parent)
            #print "Parent node id %s" % (parent_id)
    non_num = re.compile(r'[^\d.]+')
    node_id = get_node_id(tree_id, node)
    node_id = non_num.sub('', str(node_id))
    #print "Node is %s" % (node)
    #print "Node ID is %s" % (node_id)
    if not node_id:
        if parent:
            node_id = add_node_to_tree(tree_id, parent_id, node)
            node_id = non_num.sub('', str(node_id))
            #print "Node ID is %s" % (node_id)
        else:
            node_id = add_node_to_tree(tree_id, None, node)
            node_id = non_num.sub('', str(node_id))
            #print "Node ID is %s" % (node_id)
    addcmd = "%s/cli/add_tree.php --type=node --node-type=host --tree-id=%s --parent-node=%s --host-id=%s" \
            % (cactihome, tree_id, node_id, host_id)
    if options.verbose:
        print addcmd
    for line in os.popen(addcmd).readlines():
        if options.verbose:
            print "%s" % (line),
    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")

def get_awesome_hosts(location=None, server=None):
    if options.verbose: sys.stderr.write(">>DEBUG start - " + funcname() + 
                            "()\n")
    print "Grabbing ASDB Server list"
    noproduct = ['UNKNOWN']
    noenvironment = ['UNKNOWN', 'dead', 'inactive', 'new', 'retired', 'available', 'RMA',
            'InventoryManagement', 'ScrapRecycled']
    nopurpose = ['UNKNOWN', 'reserved', 'RMA']

    cachefile = '/tmp/asdb_servers.cache'
    hostlist = []
    if not options.cache:
        url="http://" + options.awesome + "/servers/data/data/?format=json"
        if location is not None:
            url += '&location__name=%s' % (location)
        if server is not None:
            url += '&name=%s' % (server)
        response=urllib.urlopen(url).read()
        hosts = simplejson.loads(response)
        cf = open(cachefile, 'w')
        pickle.dump(hosts, cf)
        cf.close()
    else:
        cf = open(cachefile)
        hosts = pickle.load(cf)

    for host in hosts:
        graph = 1
        host['product'] = re.compile('(\.|-|_| )').sub('', str(host['product']['name']))
        host['purpose'] = re.compile('(\.|-|_| )').sub('', str(host['purpose']['name']))
        host['environment'] = re.compile('(\.|-|_| )').sub('', str(host['environment']['name']))
        host['location'] = re.compile('(\.|-|_| )').sub('', str(host['location']['name']))
        if 'os' in host.keys():
            if 'freebsd' in host['os'].lower():
                host['os'] = 'os-freebsd'
            elif 'linux' in host['os'].lower():
                host['os'] = 'os-linux'
            else:
                host['os'] = None
        if noproduct.count(host['product']): graph = 0
        if noenvironment.count(host['environment']): graph = 0
        if nopurpose.count(host['purpose']): graph = 0
        if host['tags'].has_key('nograph'): graph = 0
        if host['tags'].has_key('graph'): graph = 1
        template = 'ip-%s-%s' % (host['product'], host['purpose'])
        new = 0
        if graph:
            try:
                hosttest = do_sql("SELECT hostname FROM host WHERE hostname='%s'" % (host['name']))[0]
            except:
                if options.verbose: print "Adding %s/%s to hostlist" % (host['name'], template)
                new = 1
            else:
                new = 0
        host['snmp'] = None
        if host.has_key('related') and host['related'].has_key('option'):
            if host['related']['option'].has_key('SNMP_COMMUNITY'):
                host['snmp'] = host['related']['option']['SNMP_COMMUNITY']['value']
        hostlist.append({'name': host['name'], 'template': template, 'graph': graph, 'new': new,
                'product': host['product'], 'purpose': host['purpose'], 'location': host['location'],
                'os': host['os'], 'snmp': host['snmp']})
        products[host['product'].lower()] = 1

    if options.verbose: sys.stderr.write(">>DEBUG end    - " + funcname() + 
                            "()\n")
    return (hostlist)


if __name__ == '__main__':
    options = init()

    outfile = open("/tmp/ac-new.txt", "w")

    cacti_hosts = get_cacti_hosts()
    conn = init_cdb()
    cursor = conn.cursor()

    errors = 0
    x = 0
    products = {}
    # Need to do Asdb first so we can populate the product dictionary!
    if options.host is not None:
        role_hosts = []
        asdb_hosts = get_awesome_hosts(server=options.host)
    elif options.location is not None:
        role_hosts = []
        asdb_hosts = get_awesome_hosts(location=options.location)
    elif options.rolemaps:
        role_hosts = get_awesome_rolemaps()
        asdb_hosts = []
    else:
        role_hosts = get_awesome_rolemaps()
        asdb_hosts = get_awesome_hosts()
    print "Processing"
    for host in (role_hosts + asdb_hosts):
        hostname = host['name']
        template = host['template']
        error = 0
        try:
            template_id = do_sql("SELECT id FROM host_template WHERE name = '" + template + "'")[0][0]
        except:
            template_id = None
            error = 1
        # If updating this, retain alpha order, and ABSOLUTELY be sure to test
        # Autom8 tree rules.
        notes = ''
        if host.has_key('location'):
            notes += 'Location:%s ' % (host['location'])
        if host.has_key('product'):
            notes += 'Product:%s ' % (host['product'])
        if host.has_key('purpose'):
            notes += 'Purpose:%s ' % (host['purpose'])
        if hostname in cacti_hosts:
            if options.verbose:
                print hostname + " already in cacti database"
            del cacti_hosts[hostname]
            # Disable/Re-enabable hosts per ASDB.
            if not host['graph']:
                if options.verbose:
                    print "Host %s should not be graphed, but is.  Disabling." % (hostname)
                do_sql("UPDATE host SET disabled='on' WHERE hostname='%s' AND disabled != 'on'" % (hostname))
                continue
            else:
                do_sql("UPDATE host SET disabled='' WHERE hostname='%s' AND disabled='on'" % (hostname))

            cacti_id = do_sql("SELECT host_template_id FROM host WHERE hostname = '" + hostname +"'")[0][0]
            if (template_id):
                if (cacti_id != template_id):
                    # host exists but has wrong template, fixing
                    host_id = do_sql("SELECT id FROM host WHERE hostname='%s'" % (hostname))[0][0]
                    fixtmpl = '/usr/bin/php -q '
                    fixtmpl += '%s/cli/host_update_template.php --host-template=%i --host-id=%i' % \
                            (cactihome, template_id, host_id)
                    if not options.skiphost:
                        nocare = os.popen(fixtmpl).read()
                        if options.verbose:
                            print nocare
                else:
                    # Maintain hosts.notes
                    do_sql("UPDATE host SET notes='%s' WHERE hostname='%s' AND notes !='%s'" %
                            (notes, hostname, notes))
            else:
                print("Host " + hostname + " has template id " + str(cacti_id) + 
                        " and should have missing template " + template)
                outfile.write("Host " + hostname + " has template id " + str(cacti_id) + 
                        " and should have missing template " + template + "\n")
                errors = errors + 1
                error = 1
        else:
            if not host['graph']:
                # not in cacti, not to be added.
                continue
            if host.has_key('snmp') and host['snmp'] is not None:
                community = host['snmp']
            else:
                community = options.community
            if host.has_key('discovery') and host['discovery'] == 'ping':
                pingcheck = os.popen("/bin/ping -c 1 -t 2 %s" % (hostname))
                nocare = pingcheck.readlines()
                pingclose = pingcheck.close()
                if (pingclose != None):
                    if (template_id):
                        print("Host " + hostname + " is not responding to icmp!")
                        outfile.write("Host " + hostname + " is not responding to icmp!\n")
                    else:
                        print("Host " + hostname + " is not responding to icmp! Template " + template + 
                                " does not exist.")
                        outfile.write("Host " + hostname + " is not responding to icmp! Template " + template + 
                                " does not exist.\n")
                    errors = errors + 1
                    error = 1
            else:
                snmpcheck = os.popen("/usr/bin/snmpget -v 2c -c " + community + " " + hostname + 
                        " .1.3.6.1.2.1.1.1.0 2>&1")
                nocare = snmpcheck.read()
                snmpclose = snmpcheck.close()
                if (snmpclose != None):
                    if (template_id):
                        print("Host " + hostname + " is not responding to snmp! (%s)" % (community))
                        outfile.write("Host " + hostname + " is not responding to snmp!\n")
                    else:
                        print("Host " + hostname + " is not responding to snmp! (%s)" % (community) +
                                "\n  Template " + template + " does not exist.")
                        outfile.write("Host " + hostname + " is not responding to snmp! Template " + template + 
                                " does not exist.\n")
                    errors = errors + 1
                    error = 1
            if not error:
                addhost = "%s/cli/add_device.php --description=%s --ip=%s --template=%i --notes='%s'" % \
                        (cactihome, hostname, hostname, template_id, notes)
                addhost += " --version=2 --community=%s" % (community)
                if host.has_key('availability'):
                    if host['availability'] == 'ping':
                        addhost += ' --avail=ping --ping_method=icmp'
                if options.verbose:
                    print addhost
                if options.skiphost: continue
                for line in os.popen(addhost).readlines():
                    if 'already exists' not in line:
                        print line,
            
        if not error:
            if not options.skiphost and not error:
                # Manage tree.
                add_host_to_tree("Location", None, host['location'], hostname)
                if 'product' in host:
                    add_host_to_tree("Product", host['product'], '%s-%s' % (host['product'], 
                            host['purpose']), hostname)
                
        time.sleep(2)
    if options.location is None:
        for hostname in cacti_hosts:
            try:
                location = hostname.split('.')[1]
            except:
                location = 'UNKNOWN'
            if options.verbose:
                print "%s in cacti, but not in ASDB or Rolemaps." % (hostname)
                print "Adding to Location tree on %s node." % (location)
            if options.skiphost: continue
            add_host_to_tree("Location", None, location, hostname)

    outfile.close()
