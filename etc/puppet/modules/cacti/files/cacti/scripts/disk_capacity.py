#!/usr/bin/python26
#==============================================================================
#      Disk Capacity Portal Report
#--------------------------------------------------------------------
# NAME:            disk_capacity.py
#
# VERSION:         0.91
#
# DESCRIPTION:     Disc Capacity Report for POrtal
#
#                  For a given Producr/Purpose /mount provids a report  
#                  which shows when the capacity of a server will reach 90% 
#         
# CRREATED:        05/26/2010
# CALL:            
#
# LAST MOD:        xx/xx/xxxx
#====================================================================
#		Modification history
#---------------------------------------------------------------------
#  Author    : Data     : Version : Description
#*********************************************************************
# M.Gavartin : 05/26/10 : 0.9     :  First Created
#=====================================================================
import datetime
import MySQLdb
import optparse
import os 
import sys
import urllib
import urllib2
import pprint
import simplejson
import locale
import datetime
from datetime import timedelta
import socket

# Give up trying remote connections if socket not obtained in reasonable time
socket.setdefaulttimeout(20)

#------------------------------------------------------------------------------
def init():
    usage = "%prog [options] "
    opt_parser = optparse.OptionParser(usage=usage)
    
    opt_parser.add_option('-v', '--verbose', dest='verbose',
                            action="store_true", default=False,
                            help="Print verbose error information.")
    opt_parser.add_option('--csv', dest='csv',
                            action="store_true", default=False,
                            help="csv output")
    opt_parser.add_option("-d", "--rradir", type="string", dest="rradir",
                            default="/data/rra", help="RRA directory, default: /data/rra")
    opt_parser.add_option("-r", "--rrdtool", type="string", dest="rrdtool",
                            default="/usr/bin/rrdtool",
                            help="RRDTool binary, default: /usr/bin/rrdtool")
    opt_parser.add_option("-a", "--asdb", type="string", dest="asdb",
                            default="asdb.ironport.com",
                            help="Awesome VIP.")
    opt_parser.add_option("-H", "--host", type="string", dest="host",
                            help="Host Name. Default - no host name specifyed")
    opt_parser.add_option("-m", "--mount", type="string", dest="mount",
                            help="mount Name. Default - no mount specifyed")
    opt_parser.add_option("--product", type="string", dest="product",
                            help="Product. Default - no Product specifyed - all")
    opt_parser.add_option("--env", type="string", dest="env",
                            default="prod",
                            help="Environment. Default - no Environment specifyed - prod")
    opt_parser.add_option("--purpose", type="string", dest="purpose",
                            help="Purpose. Default - no purpose specifyed - all")
    opt_parser.add_option("-c", "--cf", type="string", dest="cf",
                            default="AVERAGE",
                            help="CF to poll, default: AVERAGE")
    opt_parser.add_option("-s", "--start", type="string", dest="start",
                            default="-30d",
                            help="Start time, default: -30d")
    opt_parser.add_option("-e", "--end", type="string", dest="end",
                            default="-2d",
                            help="End time, default: -2d")
    opt_parser.add_option("-R", "--resolution", type="string", dest="resolution",
                            default="86400",
                            help="End time, default: 86400 = 1 day")
    opt_parser.add_option('--nohdr', dest='noheader',
                            action="store_true", default=False,
                            help="No header in the output")
    opt_parser.add_option('--float', dest='float',
                            action="store_true", default=False,
                            help="Calculate Start dynamicaly based on tolerance")
    opt_parser.add_option("--days", type="int", dest="days_to_show",
                            default=10000000,
                            help="Show if days left less then DAYS. Default - shows all")
    opt_parser.add_option("--red", type="int", dest="red_threshold",
                            default=60,
                            help="Red if < than RED days left")
    opt_parser.add_option("--usage", type="int", dest="usage_threshold",
                            default=75,
                            help="Usage % red if >")

    opt_parser.add_option("--last24increase", type="float", dest="last24_threshold",
                            default=1,
                            help="Last 24 % red if >")

    opt_parser.add_option('--nomount', dest='nomount',
                            action="store_true", default=False,
                            help="Show mounts with no Cacti")
    opt_parser.add_option('--summary', dest='summary',
                            action="store_true", default=False,
                            help="Outputs a summary report")
    opt_parser.add_option('--ataglance', dest='ataglance',
                            action="store_true", default=False,
                            help="Outputs a summary report for AtAGlance page")
    opt_parser.add_option("-t", "--tolerance", type="int", dest="tolerance",
                            default="5",
                            help="% of usage drop which does not affect start date, default:  5")

    try:
        (options, args) = opt_parser.parse_args()
    except optparse.OptParseError:
        print "Error: Invalid command line arguments."
        opt_parser.print_help()
        sys.exit(1)

    return(options)

#------------------------------------------------------------------------------
def date_str():
    date2 =  (str(datetime.datetime.today())).split('.')
    return(date2[0])

#------------------------------------------------------------------------------
def log(options, message):
    """ 
    Output to log file 
    """
    if options.verbose:
        print date_str() + ' ' + message
    return

#------------------------------------------------------------------------------
def init_db(options):
    conn = MySQLdb.connect (host = "ops-cacti-vdb-m1.vega.ironport.com",
                            user = "cactiuser",		# dashboard
                            passwd = "cact1pa55",	# asdf1234
                            db = "cacti")
    log(options, "Connected to Cacti")
    return conn

#------------------------------------------------------------------------------
def do_sql(options, sql):
  
    conn = init_db(options)
    cursor = conn.cursor()
    log(options, "Start Cacti query")
    cursor.execute(sql)
    log(options, "End Cacti query")
    result = cursor.fetchall()
    conn.commit()
    conn.close()
    
    if options.verbose:
        print result
        print len(result)

    return result

def compose_query(optrions, host, mount = '%', cache_field = 'dskPath', template_name ='%space%'):

    query = "SELECT host_template.name, host.hostname,\
             data_template_data.data_source_path,\
             data_template_data.name_cache, host_snmp_cache.field_value, graph_local.id \
             FROM data_template_data, data_local, data_template, host, host_template, host_snmp_cache, graph_local \
             WHERE data_template_data.local_data_id = data_local.id \
             AND data_local.data_template_id = data_template.id and host.disabled != 'on' \
             AND host.host_template_id = host_template.id \
             AND data_local.host_id = host.id AND host.hostname like '"\
             +  host +\
             "' AND host_snmp_cache.field_value LIKE '" + mount +\
             "' AND data_template.name like '" + template_name +\
             "' AND data_local.host_id = host_snmp_cache.host_id \
             AND data_local.snmp_query_id = host_snmp_cache.snmp_query_id \
             AND data_local.snmp_index = host_snmp_cache.snmp_index \
             AND  graph_local.host_id = host.id \
             AND graph_local.snmp_query_id = data_local.snmp_query_id \
             AND graph_local.snmp_index = data_local.snmp_index \
             AND host_snmp_cache.field_Name = '" + cache_field + "'" 

    return query


#------------------------------------------------------------------------------
def get_end_date_for_mount(options, host, mount, source, percent=90):
    """
    Calculate the date when the capacity reaches percent capacity
    """
    locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')
    giga = 1024. * 1024

    vol = ''
    netapp = ''
    # get metadata from Cacti DB
    if source.find(':/vol') >= 0:
        # nfs
        # get metadata from Cacti DB
        (host, vol) = source.split(':')  # host - netapp
        vol = vol + '/'
        netapp = host
        if '-vlan' in netapp:
            #remove -vlanxx from netapp1-vlanxx.soma.ironport.com (Ex)
            netapp = netapp.replace('-' + netapp.split('.')[0].split('-')[1], '')

        sql = compose_query(options, host, vol, 'dfFileSys', '%')

    else:
        #device
        sql = compose_query(options, host, mount)

    result = do_sql(options, sql)
    if len(result) <= 0:
        if options.nomount:
            return {'days_left': '0', 'total': 'N/A', 'used': 'N/A',
                   'percent_used': 'N/A', 'usage_rate': 'N/A', 'last_24h_usage': 'N/A', 'last_24h_percent': 'N/A', 
                   'graph_id': 'N/A', 'netapp': netapp, 'vol': vol} 
        return '' 

    data_source_path = result[0][2].replace('<path_rra>',options.rradir)
    graph_id = str(result[0][5])
    log (options, data_source_path)

    cacti_cmd = '%s fetch %s %s -s %s -e %s -r  %s 2>&1' % (options.rrdtool,
        data_source_path, options.cf, options.start,
        options.end, options.resolution) 
    log(options, cacti_cmd)

    # get Cacti data from rra
    output = os.popen(cacti_cmd).readlines()
    dsources = output[0].split()
    if dsources[0].startswith('ERROR'):
        log(options, output[0])
        return ''
    if options.verbose:
        for line in output:
            print line.replace('\n','')

    # calculate Days Left
    start_i = get_start_point(options, output)
    if source.find(':/vol') >= 0:
        (s_time, s_total, s_free, s_used, s_percent)  = output[start_i].replace(':', '').split(' ')
        (e_time, s_total, e_free, e_used, e_percent)   = output[-1].replace(':', '').split(' ')
        if float(s_percent) != 0. and float(e_percent) != 0. : 
            s_free = str(100*float(s_used)/float(s_percent) - float(s_used))  # there are some nan for Total and Avail
            e_free = str(100*float(e_used)/float(e_percent) - float(e_used))
        else:
            s_free = '0'
            e_free = '0'
    else:
        (s_time, s_free, s_used)  = output[start_i].replace(':', '').split(' ')
        (e_time, e_free, e_used)   = output[-1].replace(':', '').split(' ') 


    last_24h_usage = get_last_24h_usage(options, source, data_source_path)/giga

    total  = float(e_free)/giga + float(e_used)/giga
    diff = float(e_used)/giga - float(s_used)/giga
    days = (float(e_time) - float(s_time))/(60*60*24)
    usage_rate = diff/days
    limit = total*float(percent)*.01 - float(e_used)/giga
    try:
        percent_used = 100.0*float(e_used)/total/giga
    except:
        percent_used = 100.

    if usage_rate == 0:
        days_left = 10000000.
    else:
        days_left = limit/usage_rate
        if days_left < 0: days_left = 1000000.

    total_c = locale.format("%.0f", total, grouping=True)
    used_c = locale.format("%.0f", float(e_used)/giga, grouping=True)
    diff_c = locale.format("%.0f", diff, grouping=True)
    days_left_c = locale.format("%.0f", days_left, grouping=True)
    if days_left_c == 'nan':
        days_left_c = '0'
    usage_rate_c = locale.format("%.3f", usage_rate, grouping=True)
    if usage_rate_c == '-0.000': usage_rate_c = '0.000'
    percent_used_c = locale.format("%.1f", percent_used, grouping=True)
    last_24h_usage_c = locale.format("%.2f", last_24h_usage, grouping=True)
    try:
        last_24h_percent = 100.* last_24h_usage/ (float(e_used)/ giga)
    except:
        last_24h_percent = 100.

    last_24h_percent_c = locale.format("%.2f", last_24h_percent, grouping=True)

    if options.verbose:
        print 'total: ', total
        print 'diff: ', diff
        print 'days: ', days
        print 'usage rate: ', usage_rate
        print 'limit: ', limit
        print 'days_left: ', days_left
        print 'graph_id: ', graph_id
        print 'netapp: ', netapp
        print 'vol: ', vol
        print 'used: ',  str(float(e_used)/giga)
        print 'last 24h usage:', last_24h_usage
        print 'last 24h percent:', last_24h_percent


    result = {'days_left': days_left_c, 'total': total_c, 'used': used_c,
               'percent_used': percent_used_c, 'usage_rate':usage_rate_c, 'graph_id': graph_id,
               'netapp': netapp, 'vol': vol, 'last_24h_usage': last_24h_usage_c,
               'last_24h_percent': last_24h_percent_c } 
    return result

#-----------------------------------------------------------------------
def get_last_24h_usage(options, source, data_source_path):

    cacti_cmd = '%s fetch %s %s -s %s -e %s -r  %s 2>&1' % (options.rrdtool,
        data_source_path, options.cf, '-24h','-0h', 300) 
    log(options, cacti_cmd)

    # get Cacti data from rra
    output = os.popen(cacti_cmd).readlines()
    dsources = output[0].split()
    if dsources[0].startswith('ERROR'):
        log(options, output[0])
        return 0.

    """
    too much
    if options.verbose:
        for line in output:
            print line.replace('\n','')
    """

    # find fisrst and last entry not nan
    i_last = -1
    used_offset = 1 # device
    if source.find(':/vol') >= 0:
        used_offset = 3 # nfs share

    i_first = -1
    for i in range (2, len(output) -1):
        line = output[i].split(' ')
        if line[used_offset] != 'nan':
            i_first = i
            break
    if i_first == -1:
        return 0.

    # last
    i_last = -1
    for i in range (1, len(output) -2):
        line = output[len(output)-i].split(' ')
        if line[used_offset] != 'nan':
            i_last = len(output) - i
            break
    if i_last == -1:
        return 0.
       
    if source.find(':/vol') >= 0:
        (s_time, s_total, s_free, s_used, s_percent)  = output[2].replace(':', '').split(' ')
        (e_time, s_total, e_free, e_used, e_percent)   = output[i_last].replace(':', '').split(' ')
        if float(s_percent) != 0. and float(e_percent) != 0. : 
            s_free = str(100*float(s_used)/float(s_percent) - float(s_used))  # there are some nan for Total and Avail
            e_free = str(100*float(e_used)/float(e_percent) - float(e_used))
        else:
            s_free = '0'
            e_free = '0'
    else:
        (s_time, s_free, s_used)  = output[2].replace(':', '').split(' ')
        (e_time, e_free, e_used)   = output[i_last].replace(':', '').split(' ') 
   
    if options.verbose:
        print 'i_last: ', i_last
        print 'day start: ', s_used
        print 'day end:   ', e_used

    last_24h_usage = float(e_used) - float(s_used)
    return float(last_24h_usage)
    
#-----------------------------------------------------------------------
def get_start_point(options, data):
    """
    Find which rrd data point to use as the start.
    """
    if options.float:
        """
        pass
        for i in range(1,len(output) -2):
            (x, x, used_curr) = output[-i].split('\t')
            (x, x, used_prev) = output[-i-1].split('\t')
            if (used_prev - used_prev) >  used_prev * (options.tolerance/100):
        """          
    else: start_i = 2
    return start_i
#-----------------------------------------------------------------------
def get_list(options, hostname, product, purpose, mount):
    """
    Returns a list of 
    <product> <purpose> <mount>
    """

    url="http://" + options.asdb + "/servers/data/?format=json"
    url += "&environment__name=" + options.env

    if hostname:
        url += "&name=" + hostname

    else:
       if product:
           url += "&product__name=" + product
       if purpose:
           url += "&purpose__name=" + purpose
    log(options, url)

    response = urllib.urlopen(url).readlines()
    hosts = simplejson.dumps(response)
    hosts = simplejson.loads(simplejson.loads(hosts)[0])

    #pp = pprint.PrettyPrinter()
    #pp.pprint(hosts)

    result=[]
    
    for host in hosts:
        all_mounts = host['related']['filesystem']
        for value in all_mounts.itervalues():
            if options.verbose:
                print 'mount:', mount, ' mount:'  , value['mount']
            if (mount and value['mount'] == mount) or (mount == None):
                 if value['mount'] == '/host' or value['mount'] == '/net':
                      # dont need them
                      continue
                 result.append({'server': host['name'],
                                'product': host['product']['name'],
                                'purpose': host['purpose']['name'],
                                'mount': value['mount'],
                                'source': value['source']
                              }) 
    if options.verbose:
        pp = pprint.PrettyPrinter()
        print '----------------- Found:'          
        pp.pprint(result)
    return result
     
#----------------------------------------------------------------------
def detail_report(options, output):

    if options.csv:
        if options.noheader == False:
            header = 'Server_string\t' +\
                     'Product_string\t' +\
                     'Purpose_string\t' +\
                     'Mount_string\t' +\
                     'Netapp\t' +\
                     'Vol\t' +\
                     'Total (Gb)\t' +\
                     'Usage %\t' +\
                     'Daily Usage (GB)\t' +\
                     'Last 24h (GB)\t' +\
                     'Last 24h %\t' +\
                     'Days Left\t' +\
                     'End Date\t' +\
                     'Mount_string#link\t' +\
                     'Usage %#color\t' +\
                     'Last 24h %#color\t' +\
                     'Days Left#color'
            print header
        for row in output:
            days_left = int((row['days_left']).replace(',',''))
            if days_left > 1500:
                end_date = '---> Future'
            else:
                end_date = (datetime.date.today() + timedelta(days=days_left)).strftime('%b %d, %Y')
            output_row = row['server'] + '\t' +\
                         row['product'] + '\t' +\
                         row['purpose'] + '\t' +\
                         row['mount'] + '\t' +\
                         row['netapp'] + '\t' + \
                         row['vol'] + '\t' + \
                         row['total'] + '\t' +\
                         row['percent_used'] + '\t' +\
                         row['usage_rate'] + '\t' +\
                         row['last_24h_usage'] + '\t' +\
                         row['last_24h_percent'] + '\t'
            if row['total'] != 'N/A' and row['total'] != 'nan'  :    
                output_row += row['days_left'] + '\t' +\
                          end_date + '\t' +\
                         'https://cacti-www1.soma.ironport.com/cacti/graph.php?action=view&local_graph_id=' + row['graph_id'] + '&rra_id=all'

                if float(row['percent_used']) > float(options.usage_threshold):
                   output_row += '\tRed'
                else:
                   output_row += '\t'

                if float(row['last_24h_percent'])  > options.last24_threshold:
                   output_row += '\tRed'
                else:
                   output_row += '\t'

                if int((row['days_left']).replace(',','')) < options.red_threshold:
                   output_row += '\tRed'
                else:
                   output_row += '\t'
            else:
                output_row += 'N/A\tN/A\t\t\t\t'

            print output_row
    else:
       pp = pprint.PrettyPrinter()
       pp.pprint(output)

#----------------------------------------------------------------------
def summary_report(options, output):

    if options.csv:
        summary = {}
        for mount in output:
            if mount['product'] not in summary:
                # initialize ne wproduct
                summary[mount['product']] = {
                   'mount_num': 0,
                   'nfs_num': 0,
                   'NA_num' :0,
                   'lt_red': 0,
                   'lt_days': 0,
                   'gt_usage_threshold': 0,
                   'gt_last24_threshold': 0
                 }
            # process
            summary[mount['product']]['mount_num'] +=1
            if mount['netapp'] != '':
                 summary[mount['product']]['nfs_num'] +=1

            if mount['total'] == 'N/A':
                 summary[mount['product']]['NA_num'] +=1
            else:
                if int(mount['days_left'].replace(',','')) <  int(options.red_threshold):
                    summary[mount['product']]['lt_red'] +=1
           
                if int(mount['days_left'].replace(',','')) <  int(options.days_to_show):
                    summary[mount['product']]['lt_days'] +=1

                if float(mount['percent_used'].replace(',','')) >  float(options.usage_threshold):
                    summary[mount['product']]['gt_usage_threshold'] +=1

                if float(mount['last_24h_percent'].replace(',','')) >  options.last24_threshold:
                    summary[mount['product']]['gt_last24_threshold'] +=1

        # format output
        if options.verbose:
            pp = pprint.PrettyPrinter()
            pp.pprint(summary)

        if options.ataglance:
             header = 'Product_string\t' +\
                'Total Mounts\t' +\
                '> ' + str(options.usage_threshold) + '% used\t' +\
                '> ' + str(options.last24_threshold) + '% last 24h_desc\t' +\
                '< ' + str(options.last24_threshold) + '% last 24h_desc#color\t' +\
                'Product_string#link' 
     
        else:       
            header = 'Product_string\t' +\
                'Total Mounts\t' +\
                'NFS Mounts\t' +\
                'Mounts w/No Data\t' +\
                '< ' + str(options.red_threshold) + ' days_desc\t' +\
                '< ' + str(options.days_to_show) +  ' days\t' +\
                '> ' + str(options.usage_threshold) + '% used\t' +\
                '> ' + str(options.last24_threshold) + '% last 24h\t' +\
                '< ' + str(options.red_threshold) + ' days_desc#color\t' +\
                'Product_string#link' 

        print header
        for key in summary:
            if options.ataglance:
                if summary[key]['lt_red'] == 0: continue
                 
                output_row = key + '\t' +\
                        str(summary[key]['mount_num']) + '\t' + \
                         str(summary[key]['gt_usage_threshold']) + '\t' + \
                        str(summary[key]['gt_last24_threshold']) + '\t' + \
                        'red\t'
                output_row += '/portal/disksbyproduct?product=' + key            
           
            else:
                # full report
                output_row = key + '\t' +\
                        str(summary[key]['mount_num']) + '\t' + \
                        str(summary[key]['nfs_num']) + '\t' + \
                        str(summary[key]['NA_num']) + '\t' + \
                        str(summary[key]['lt_red']) + '\t' + \
                        str(summary[key]['lt_days']) + '\t' + \
                        str(summary[key]['gt_usage_threshold']) + '\t' + \
                        str(summary[key]['gt_last24_threshold']) + '\t' 
                        
                if summary[key]['lt_red'] > 0:
                    output_row += 'red'
                output_row += '\t'
                output_row += '/portal/disksbyproduct?product=' + key 

            print output_row
                    
    else:
        pp = pprint.PrettyPrinter()
        pp.pprint(output)


#----------------------------------------------------------------------
if __name__ == '__main__':
    """
    #########################################################
    Main procedure
    #########################################################
    """
    options = init()

    #locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')
    
    host_mount_list = get_list(options, options.host, options.product, 
                          options.purpose, options.mount)

    results = []    
    for row in host_mount_list:
        result = get_end_date_for_mount(options, row['server'], row['mount'], row['source'], 90)
        if result == '':
             continue
        if int((result['days_left']).replace(',','')) > options.days_to_show:
            continue
        result['server'] = row['server']
        result['product'] = row['product']
        result['purpose'] = row['purpose']
        result['mount'] = row['mount']
        result['source'] = row['source']  # ??? 

        results.append(result)


    if options.summary:
        summary_report(options, results)

    else:
        detail_report(options, results)
