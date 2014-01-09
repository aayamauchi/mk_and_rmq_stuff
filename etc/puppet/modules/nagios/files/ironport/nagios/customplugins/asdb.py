#!/usr/bin/python26 -u
# -*- coding: ascii -*-
"""Module with generic functions for Awesome Server DB Calls.
    code template"""

import simplejson
import urllib 
import time
import random
import re
import os
import pickle

asdb = 'asdb.ironport.com'

def cache(function, args, timeout=3600):
    """pass a string matching a function, a tuple of args, and an optional timeout
    get back the output of that function, if there is no cache younger than timeout
    otherwise get back what's in the cache."""

    cachedir = '/tmp/asdb-cachedir-%s' % (os.getuid())
    cachefile = cachedir + '/%s-%s' % (function, str(args).replace(' ', '_')\
            .replace('(', ':').replace(')', ':'))
    if not os.path.isdir(cachedir):
        os.mkdir(cachedir)

    if os.path.isfile(cachefile) and os.stat(cachefile).st_mtime > (time.time() - timeout):
        cf = open(cachefile)
        result = pickle.load(cf)
        cf.close()
    else:
        try:
            # must be a smarter way to do this:
            f = globals()[function]
            if len(args) == 1:
                result = f(args[0])
            elif len(args) == 2:
                result = f(args[0], args[1])
            elif len(args) == 3:
                result = f(args[0], args[1], args[2])
            elif len(args) == 4:
                result = f(args[0], args[1], args[2], args[3])
            elif len(args) == 5:
                result = f(args[0], args[1], args[2], args[3], args[4])
            cf = open(cachefile, 'w')
            try:
                cf.write(pickle.dump(result, cf))
            except TypeError:
                # don't cache None
                pass
            cf.close()
        except:
            if os.path.isfile(cachefile):
                # If we can't hit ASDB, grab the cache
                cf = open(cachefile)
                result = pickle.load(cf)
                cf.close()
            else:
                raise

    return result
        

    
def get_product_by_hostname(hostname, servers=True):
    """pass a hostname, return a product"""
    url = 'http://%s/servers/get_product_by_host/%s' % (asdb, hostname)
    response = urllib.urlopen(url).read()
    if 'DoesNotExist' not in response:
        return response
    url = 'http://%s/nagios/get_product_by_host/%s' % (asdb, hostname)
    response = urllib.urlopen(url).read()
    if 'DoesNotExist' not in response:
        return response
    raise KeyError, "host not found"

def get_environment_by_hostname(hostname, servers=True):
    """pass a hostname, return a environment"""
    environment = ''
    done = False
    while not done:
        if servers:
            url = 'http://%s/servers/data/?format=json&name__exact=%s' % (asdb, hostname)
            response = urllib.urlopen(url).read()
            response = simplejson.loads(response)
            try:
                environment = response[0]['environment']['name']
            except:
                servers = False
            else:
                return environment
        else:
            url = 'http://%s/nagios/rolemap/data/?format=json&hostname__exact=%s' % (asdb, hostname)
            response = urllib.urlopen(url).read()
            response = simplejson.loads(response)
            try:
                environment = response[0]['environment']['name']
            except:
                done = True
            else:
                return environment
    raise KeyError, "host not found"
            

def get_purpose_by_hostname(hostname, servers=True):
    """pass a hostname, return a purpose"""
    purpose = ''
    done = False
    while not done:
        if servers:
            url = 'http://%s/servers/data/?format=json&name__exact=%s' % (asdb, hostname)
            response = urllib.urlopen(url).read()
            response = simplejson.loads(response)
            try:
                purpose = response[0]['purpose']['name']
            except:
                servers = False
            else:
                return purpose
        else:
            url = 'http://%s/nagios/rolemap/data/?format=json&hostname__exact=%s' % (asdb, hostname)
            response = urllib.urlopen(url).read()
            response = simplejson.loads(response)
            try:
                purpose = response[0]['purpose']['name']
            except:
                done = True
            else:
                return purpose
    raise KeyError, "host not found, or no purpose"
            

def get_hosts_by_product(product, environment='prod', purpose=None, location=None, nagios=False):
    """pass a product, get a list of hosts.
    if optional environment is None, return all hosts
    regardless of environment.
    if optional purpose is not None, limit query to that purpose.
    if nagios=True, exclude all HOST entries with 'nonagios' tags.
    presently, we can only retrieve nonagios for servers, not rolemaps."""
    hosts = []
    nonagios_hosts = []    

    # retrieve server list from asdb
    url = 'http://%s/servers/data/?format=json&product__name__exact=%s' % (asdb, product)
    if environment is not None:
        url += '&environment__name__exact=%s' % (environment)
    if purpose is not None:
        url += "&purpose__name__exact=%s" % (purpose)
    if location is not None:
        url += "&location__name__exact=%s" % (location)
    response = urllib.urlopen(url).read()
    response = simplejson.loads(response)
    for entry in response:
        hosts.append(entry['name'])
    if nagios:
        # retrieve same server list, but only those with nonagios tag
        nonagios_url = "%s&tags__name=nonagios" % (url)
        response = urllib.urlopen(nonagios_url).read()
        response = simplejson.loads(response)
        for entry in response:
            nonagios_hosts.append(entry['name'])

    # rolemaps
    url = 'http://%s/nagios/rolemap/data/?format=json&product__name__exact=%s' % (asdb, product)
    if environment is not None:
        url += '&environment__name__exact=%s' % (environment)
    if purpose is not None:
        url += "&purpose__name__exact=%s" % (purpose)
    response = urllib.urlopen(url).read()
    response = simplejson.loads(response)
    for entry in response:
        hosts.append(entry['hostname'])

    # exclude nonagios hosts
    if nagios:
        s_hosts = set(hosts)
        s_nonagios_hosts = set(nonagios_hosts)
        hosts = list(s_hosts.difference(s_nonagios_hosts))

    return hosts

def get_product_by_service(hostname, service):
    """pass a hostname and service, return a product.  Only works for
    netapp volumes, currently."""
    url = 'http://%s/nagios/netapp/data/?format=json&name=%s' % (asdb, hostname)
    response = urllib.urlopen(url).read()
    if 'DoesNotExist' not in response:
        response = simplejson.loads(response)[0]['related']['netappaggr']
        for aggr in response.keys():
            volumes = response[aggr]['related']['netappvol']
            for vol in volumes.keys():
                if volumes[vol]['name'] in service:
                    return volumes[vol]['product']
    raise KeyError, "host & service not found"


def ishost(hostarg):
    """internal call for disambiguating between env-prod-purpose and prod-foo-db-m1.blah.com"""
    hostwords=['blade','.com','.net','.org','ironport']
    for w in hostwords:
        if w in hostarg:
           return True
           break
        
    return False

def asdb_server_req(req):
    """basic Req into Servers model. Need to do something not in Awesome urls.py ?---Start here"""
    """This returns the results as a string to make it more mungeable by the caller"""
    results = []
    trim = []
    rdict = {}
    url = "http://%s/servers/%s" % (asdb,req)
    response = urllib.urlopen(url).read()
    if 'DoesNotExist' not in response:
        return response
    else: 
        return None
   
def roledata(rolemap):
    """Dump the full data record for a rolemap as a JSON object """
    url='http://%s/nagios/rolemap/data/?format=json&hostname__exact=%s' % (asdb, rolemap)
    response = urllib.urlopen(url).read()
    if 'DoesNotExist' not in response:
       rec=simplejson.loads(response)
       return rec
    else:
         return None

def hostdata(host):
    """Dump the full data record for a host as a JSON object """
    host_url="data/?format=json&name__exact=%s" % (host)
    http_response=asdb_server_req(host_url)
    if 'DoesNotExist' not in http_response:
       host_rec=simplejson.loads(http_response)
       return host_rec
    else:
         return None

def hostdata_as_str(host):
    """Dump the full data record for a host as a string. """
    host_url="data/?name__exact=%s" % (host)
    http_response=asdb_server_req(host_url)
    if 'DoesNotExist' not in http_response:
       return http_response
    else:
         return None

def asdb_groupdata(env,prod,purp):
    """Dump the full data records as a list of dictionaries for hosts in env/prod/purp"""

    hd={}
    hostlist_cooked=[]
    url="data/?environment__name=%s&product__name=%s&purpose__name=%s" % (env,prod,purp)
    http_response=asdb_server_req(url)
    raw=re.split(r'### End:',http_response)
    for i in xrange((len(raw))-1):
        hd=response_to_dict(raw[i])
        hostlist_cooked.append(hd)
    return hostlist_cooked

def get_hosts_by_product_purpose(env,prod,purp):
    """provide an environment-product-purpose, get back the hosts w/ that Awesome tag"""
    hosts=[]
    host_url="data/?environment__name=%s&product__name=%s&purpose__name=%s&format=json" % (env,prod,purp)
    http_response=asdb_server_req(host_url)
    host_rec=simplejson.loads(http_response)
    for h in host_rec:
        hosts.append(h['name'])
    return hosts

def response_to_dict(resp):
     """take an http response and return a dictionary if you don't want to use JSON for some reason"""
     trim_res=[]
     reslist=[]
     res_d={}
     reslist=resp.split()
     for i in xrange((len(reslist))-2):
          if reslist[i].startswith("awesome_"):
              if not reslist[i].startswith("awesome_package") :
                 trim_res.append(reslist[i])
     for i in xrange((len(trim_res))-2):
          k,v = trim_res[i].split('=')
          res_d[k]=v
     return res_d

def epp_str(hostname):
     """env-prod-purpose as a string"""
     server_d = {} 
     server_d = hostdata(hostname) 
     try: 
         server_prod = server_d['awesome_product'].strip('\"')
         server_env = server_d['awesome_environment'].strip('\"')
         server_purp = server_d['awesome_purpose'].strip('\"')
     except:
         server_env="unknown"

         server_prod="unknown"
         server_purp="unknown"
     epp_str = "%s-%s-%s" % (server_env,server_prod,server_purp)
     return epp_str

def epp_list(hostname):
     """env-prod-purpose as a list"""
     server_d={}
     server_l=[]
     server_d = hostdata(hostname)
     try:
         server_l.append(server_d['awesome_environment'].strip('\"'))
         server_l.append(server_d['awesome_product'].strip('\"'))
         server_l.append(server_d['awesome_purpose'].strip('\"'))
     except:
         server_l.append("unknown")
         server_l.append("unknown")
         server_l.append("unknown")
     return server_l

def serial(hostarg):
    """Return the serial number for a given hostarg. Provide a hostname, get that unique serial. Provide an EPP, get back everything for that group"""
    serial_l=[]
    isit=ishost(hostarg)
    if ( isit > 0 ):
      url='data/?format=json&name__exact=%s' % hostarg
      host_rec=asdb_server_req(url) 
      host_rec=simplejson.loads(host_rec)
      server_serial = host_rec[0]['serial']
      return server_serial.strip('\"')   
    else:
      env,prod,purp=hostarg.split('-')
      hostlist=asdb_groupdata(env,prod,purp)
      for i in xrange((len(hostlist))-1):
         serial_l.append(hostlist[i]['awesome_name'])
         serial_l.append(hostlist[i]['awesome_serial'])
 
    return serial_l

def rack(hostarg):
    """Return the rack number for a given hostarg. Provide a hostname, get that unique rack. Provide an EPP, get back everything for that group"""
    """Blades, admittedly, present a bit of a special case"""
    rack_d={}
    rack_l=[]
    isit=ishost(hostarg)
    if ( isit >0 ):  
      rack_d = hostdata(hostarg)
      server_rack = rack_d['awesome_rack']
      return server_rack.strip('\"')  
    else: 
      env,prod,purp=hostarg.split('-')
      racklist=asdb_groupdata(env,prod,purp)
      for i in xrange((len(racklist))-1):
        rack_l.append(racklist[i]['awesome_name'])
        rack_l.append(racklist[i]['awesome_rack'])
      return rack_l 

def dblist(db_env,db_prod,db_type,nagios=False):
    """Return a list of databases tagged with the provided env-prod tag,
    if nagios=True, exclude all entries with 'nonagios' tags"""
    dbq = "list/?environment__name=%s" % (db_env)
    if (db_type == "dbm"): 
        dbquery = "%s&purpose__name__contains=dbm" % (dbq)
        dbquery2 = "%s&tags__name__exact=dbm" % (dbq)
    elif (db_type == "dbs"):
        dbquery = "%s&purpose__name__contains=dbs" % (dbq)
        dbquery2 = "%s&tags__name__exact=dbs" % (dbq)
    else:
        dbquery = "%s&purpose__name=%s" % (dbq, db_type)
        dbqueryq = None

    if db_prod is not None:
        dbquery += "&product__name=%s" % (db_prod)
        if dbquery2 is not None:
            dbquery2 += "&product__name=%s" % (db_prod)

    dbstr = asdb_server_req(dbquery)
    dblist = set(dbstr.split())
    if dbquery2 is not None:
        dbstr = asdb_server_req(dbquery)
        dblist = dblist.union(dbstr.split())

    if nagios:
        exclude = asdb_server_req(dbquery + "&tags__name=nonagios").split()
        dblist = dblist.difference(exclude)
        if dbquery2 is not None:
            exclude = asdb_server_req(dbquery2 + "&tags__name=nonagios").split()
            dblist = dblist.difference(exclude)

    return dblist

def epp_members(host_env,host_prod):
    """Convenience function to return a list of 'members' or 'neighbors' of a given host"""
    neighbor_str = "list/?environment__name=%s&product__name=%s&purpose__name=app" % (host_env.strip('\"'),host_prod.strip('\"'))
    nlist = asdb_server_req(neighbor_str)
 
    return nlist

def any(env,prod,purp):
    """For a given env/product/purpose/, return a random host from that list"""
    """Useful for where you need to 'do this on any prod-foo-app host' """
    try:
       hostlist=get_hosts_by_product_purpose(env,prod,purp)
       random.seed()
       hindex = random.randint(0,(len(hostlist))-1)
       return hostlist[hindex]
    except:
       print "Bad argument: %s"
       return -1  
