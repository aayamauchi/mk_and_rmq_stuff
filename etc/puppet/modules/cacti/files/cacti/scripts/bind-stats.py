#!/usr/bin/python26

from os import stat, path, mkdir, geteuid
from time import time

import sys
import urllib2
import xml.etree.ElementTree as ET
from pprint import pprint, pformat

cache_age = 270
cache_dir = '/tmp/cache-' + str(geteuid()) + '/'
cache_file = '%s/bind__%s' % (cache_dir, sys.argv[1])

try:
    if not path.exists(cache_dir):
        mkdir(cache_dir)
except:
    print 'Error creating cache directory'
    raise

if path.exists(cache_file) and (time() - stat(cache_file).st_mtime) < cache_age:
    try:
        f = open(cache_file)
    except:
        print 'Error reading cachefile.'
        raise
    resp = f.read()
else:
    try:
        resp    = urllib2.urlopen('http://' + sys.argv[1] + '/').read()
    except:
        print 'Error connecting.'
        raise
    try:
        f = open(cache_file, 'w')
    except:
        print 'Error writing cachefile.'
        raise
    f.write(resp)
    f.close()

try:
    xml     = ET.fromstring(resp)
except:
    print 'Error parsing XML'
    raise

def wstrip(text):
    if text is None:
        text = ''
    return text.replace(' ', '').replace('\n', '')

stats = {}

def climb_tree(element):
    stats = {}
    for child in list(element):
        if wstrip(child.text):
            stats[child.tag] = wstrip(child.text)
        else:
            _stats = climb_tree(child)
            if _stats.has_key('name'):
                name = _stats['name']
                del(_stats['name'])
                if _stats.has_key('counter'):
                    _stats = _stats['counter']
                stats['%s__%s' % (child.tag, name)] = _stats
                
            else:
                stats[child.tag] = _stats
    return stats

def parse_dict(stats, args):
    keys        = ''
    depth       = 1
    for key in args:
        keys += '%s/' % (key)
        try:
            # descend until keyerror
            stats = stats[key]
        except KeyError:
            if key.endswith('*') or key.endswith('?'):
                first   = True
                wkey    = key[:-1]
                _stats  = {}
                for _key in stats.keys():
                    if _key.startswith(wkey):
                        if key.endswith('*'):
                            _stats[_key.replace(wkey, '')], _keys = parse_dict(stats[_key], args[depth::])
                        else:
                            stat, _keys = parse_dict(stats[_key], args[depth::])
                            if stat != {}:
                                for s in stat.keys():
                                    _stats['%s__%s' % (_key.replace(wkey, ''), s.split('__',1)[-1])] = stat[s]
                            else:
                                continue
                        if first:
                            keys += _keys
                            first = False
                stats = _stats
                break
            elif key not in ['print', 'keys', 'keysn', 'keys__', 'keys__n', '_query', 'query']:
                print 'err retreiving %s' % (keys)
                pprint(stats.keys())
                sys.exit(3)
        except TypeError:
            #pprint(stats)
            #print key
            break
        depth += 1
    return stats, keys

stats = climb_tree(xml)['bind']['statistics']

if len (sys.argv) < 3:
    pprint(stats)
else:
    stats, keys = parse_dict(stats, sys.argv[2::])

    if keys.endswith('/print/'):
        for key in stats.keys():
            if '__' in key and hasattr(stats[key], 'keys') and 'counter' in stats[key].keys():
                print '%s:%s' % (key.split('__',1)[-1].replace('!', '_'), stats[key]['counter']),
            elif stats[key] != {}:
                print '%s:%s' % (key.split('__',1)[-1].replace('!', '_'), stats[key]),

    elif keys.endswith('/keys/') or keys.endswith('/keysn/'):
        for key in stats.keys():
            print key,
            if keys.endswith('n/'):
                print
    elif keys.endswith('/keys__/') or keys.endswith('/keys__n/'):
        for key in stats.keys():
            print key.split('__',1)[-1],
            if keys.endswith('n/'):
                print
    elif keys.endswith('query/'):
        for key in stats.keys():
            if keys.endswith('/_query/'):
                print key + ':' + key.split('__',1)[0]
            elif keys.endswith('/query/'):
                print key + ':' + key.split('__',1)[-1]
    else:
        if stats == {}:
            print 0
        else:
            print(stats)
sys.exit(0)

"""
./bind-stats.py adns1.ironport.com server queries-in print
/usr/share/cacti/cli/cacti_build-templates.py --script "<path_cacti>/scripts/bind-stats.py <hostname> server queries-in print" --hostname adns1.ironport.com --group 'DNSKEY,Others,AAAA,IXFR,NSEC3PARAM,HINFO,AXFR,RRSIG,CNAME,NS,PTR,DS,A,ANY,TXT,SRV,MX,A6,SOA,NSEC,SPF,MAILB' --height=200 --width=500 --area --title 'BIND - Queries-In' --dstype=derive


./bind-stats.py adns1.ironport.com server requests print
/usr/share/cacti/cli/cacti_build-templates.py --script "<path_cacti>/scripts/bind-stats.py <hostname> server requests print" --hostname adns1.ironport.com --height=200 --width=500 --area --title 'BIND - Requests' --dstype=derive --group 'IQUERY,STATUS,QUERY,NOTIFY'


./bind-stats.py adns1.ironport.com memory summary print
/usr/share/cacti/cli/cacti_build-templates.py --script "<path_cacti>/scripts/bind-stats.py <hostname> memory summary print" --hostname adns1.ironport.com --height=200 --width=500 --area --title 'BIND - Memory' --group 'BlockSize,InUse,ContextSize,Lost,TotalUse'


./bind-stats.py adns1.ironport.com server sockstat__* print
/usr/share/cacti/cli/cacti_build-templates.py --script "<path_cacti>/scripts/bind-stats.py <hostname> server sockstat__* print" --hostname adns1.ironport.com --dstype=derive --height=200 --width=500 --area --title 'BIND - Sockets' --group 'FDWatchClose,FDwatchConn,FDwatchConnFail,FDwatchRecvErr,FDwatchSendErr,FdwatchBindFail!TCP4Accept,TCP4AcceptFail,TCP4BindFail,TCP4Close,TCP4Conn,TCP4ConnFail,TCP4Open,TCP4OpenFail,TCP4RecvErr,TCP4SendErr!TCP6Accept,TCP6AcceptFail,TCP6BindFail,TCP6Close,TCP6Conn,TCP6ConnFail,TCP6Open,TCP6OpenFail,TCP6RecvErr,TCP6SendErr!UDP4BindFail,UDP4Close,UDP4Conn,UDP4ConnFail,UDP4Open,UDP4OpenFail,UDP4RecvErr,UDP4SendErr!UDP6BindFail,UDP6Close,UDP6Conn,UDP6ConnFail,UDP6Open,UDP6OpenFail,UDP6RecvErr,UDP6SendErr!UnixAccept,UnixAcceptFail,UnixBindFail,UnixClose,UnixConn,UnixConnFail,UnixOpen,UnixOpenFail,UnixRecvErr,UnixSendErr'


./bind-stats.py adns1.ironport.com server nsstat__\* print
/usr/share/cacti/cli/cacti_build-templates.py --script "<path_cacti>/scripts/bind-stats.py <hostname> server nsstat__* print" --hostname adns1.ironport.com --dstype=derive --height=200 --width=500 --area --title 'BIND - NS Stats' --group 'AuthQryRej,QryAuthAns,QryDropped,QryDuplicate,QryFORMERR,QryFailure,QryNXDOMAIN,QryNoauthAns,QryNxrrset,QryRecursion,QryReferral,QrySERVFAIL,QrySuccess,RecQryRej!ReqBadEDNSVer,ReqBadSIG,ReqEdns0,ReqSIG0,ReqTCP,ReqTSIG,Requestv4,Requestv6!RespEDNS0,RespSIG0,RespTSIG,Response,TruncatedResp!UpdateBadPrereq,UpdateDone,UpdateFail,UpdateFwdFail,UpdateRej,UpdateReqFwd,UpdateRespFwd!XfrRej,XfrReqDone'


./bind-stats.py adns1.ironport.com server zonestat__\* print
/usr/share/cacti/cli/cacti_build-templates.py --script "<path_cacti>/scripts/bind-stats.py <hostname> server zonestat__* print" --hostname adns1.ironport.com --dstype=derive --height=200 --width=500 --area --title 'BIND - Zone Stats' --group 'AXFRReqv4,AXFRReqv6,IXFRReqv4,IXFRReqv6,NotifyInv4,NotifyInv6,NotifyOutv4,NotifyOutv6,NotifyRej,SOAOutv4,SOAOutv6,XfrFail,XfrSuccess'

# INDEX VIEWS (arg_index)
./bind-stats.py adns1.ironport.com views keysn
# QUERY VIEWS (arg_query)
./bind-stats.py adns1.ironport.com views query

# Resource Stats per View
./bind-stats.py adns1.ironport.com views view__external resstat__* print

# Outgoing queries per View
./bind-stats.py ns1.ironport.com views view__internal rdtype__* print

# Cache RRsets per View
./bind-stats.py ns1.ironport.com views view__internal cache rrset__* print

# Zones per View
./bind-stats.py adns1.ironport.com views view__external zones keys__
# 
# Zone Indexes
./bind-stats.py ns1.ironport.com views view__? zones keysn
# Zone Query/view
./bind-stats.py ns1.ironport.com views view__? zones _query
# Zone Query/zone
./bind-stats.py ns1.ironport.com views view__? zones query

# per View per Zone stats
./bind-stats.py adns1.ironport.com views view__external zones zone__senderbase.net/IN/external counters print

"""
