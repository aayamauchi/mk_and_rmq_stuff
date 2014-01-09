jirauser = 'nagios'
jirapass = 'thaxu1T'

import os
import MySQLdb
from pprint import pformat

output = []
debug = {}

cactihost = 'ops-cacti-vdb-m1.vega.ironport.com'
cactiuser = 'nagios'
cactipass = 'thaxu1T'
cactidb  = 'cacti'
cactiurl = 'https://cacti.ops.ironport.com/cacti/'

def init_cdb():
    global conn
    conn = MySQLdb.connect (host = cactihost,
                            user = cactiuser,
                            passwd = cactipass,
                            db = cactidb)
    return

def do_sql(sql):
    cursor = conn.cursor()
    try:
        cursor.execute(sql)
    except:
        output.append('<!-- Error executing SQL \'%s\' -->' % (sql))
        results = []
    else:
        results = cursor.fetchall()
        conn.commit()
        if not len(results):
            results = None
        elif len(results) == 1:
            results = results[0][0]
        else:
            results = results
    return results

def get_host_id(name):
    '''Get id for Cacti Host.  Return None if not present. '''
    return do_sql('''SELECT id FROM %s WHERE binary %sname='%s' ; ''' % (tname, tname, name))

def get_graph_ids(host_id, sort=None):
    '''Pass a host id, get list of graph ids, optionally sorted.'''
    sql = 'SELECT id FROM graph_local WHERE host_id=%i' % (host_id)
    if sort is not None:
        sql += ' ORDER BY %s' % (sort)
    return do_sql(sql)

def get_graph_title(graph_id):
    '''Grab the title for a graph.'''
    return do_sql('SELECT title_cache FROM graph_templates_graph WHERE local_graph_id=%i' % (graph_id))

def embed_graph(id, height=150, width=250, start=-14400, legend=False, link=True):
    '''take a graph id and some settings, return html for graph.'''
    # graph_image.php?action=view&local_graph_id=19333&graph_end=-30&graph_start=-2592000&graph_width=250&graph_height=100&&graph_nolegend=false&rra_id=1

    if not legend:
        legend = '&graph_nolegend=true'
    else:
        legend = ''

    url = 'graph_image.php?action=view&local_graph_id=%i&graph_end=-300&graph_start=%i'
    url += '&graph_height=%i&graph_width=%i&rra_id=1%s'
    url = url % (id, start, height, width, legend)
    out = ''
    if link:
        view = 'graph.php?action=view&rra_id=all&local_graph_id=%i' % (id)
        # https://cacti.ops.ironport.com/cacti/graph.php?action=view&rra_id=all&local_graph_id=31933
        out += '<a href=\'%s%s\'>' % (cactiurl, view)
    #out += '<img height=%i width=%i title=\'%s\' src=\'%s%s\'>' % \
    out += '<img title=\'%s\' src=\'%s%s\'>' % \
            (get_graph_title(id), cactiurl, url)
    if link:
        out += '</a>'
    return out

def main(host, service=None, host_s={}, service_s={}):
    '''Dump important graphs in banner, and all graphs in tab.'''
    init_cdb()
    graphs = []
    explicit = []
    tab = ''

    if host_s.has_key('_GRAPH'):
        graphs = host_s['_GRAPH'].split(';',1)[1].split(',')
    if service and service_s.has_key('_GRAPH'):
        graphs += service_s['_GRAPH'].split(';',1)[1].split(',')
    for graph in graphs:
        try:
            g = int(graph)
        except:
            continue
        else:
            explicit.append(g)
    for g in explicit:
        graphs.remove(str(g))

    if not len(graphs) and not len(explicit):
        graphs = ['ping latency',]

    try:
        global tname
        if len(do_sql('SHOW TABLES LIKE \'host\'')):
            # cacti ver < 0.8.8
            tname = 'host'
        else:
            tname = 'device'
    except:
        output.append('<!-- Error checking Cacti version -->')
    else:
        host_id = get_host_id(host)
        if (host_id is not None or len(explicit)):
            gb = False
            output.append('<table width=98% border=0>')
        if len(explicit):
            for graph in explicit:
                output.append('<tr><td align=center>')
                output.append(embed_graph(graph, height=120, width=365, start=-14400, legend=False))
                output.append('</td>')
                output.append('<td align=center>')
                output.append(embed_graph(graph, height=120, width=365, start=-172800, legend=False))
                output.append('</td>')
                output.append('<td align=center>')
                output.append(embed_graph(graph, height=120, width=365, start=-1209600, legend=False))
                output.append('</td></tr>')
                gb = True

        if host_id is not None:
            tab = '<table width=98% border=0><tr>'
            graph_ids = get_graph_ids(host_id, sort='graph_template_id')
            nl = 3
            for graph in graph_ids:
                title = get_graph_title(graph)
                words = title.lower().split('-')[1:]
                for word in words:
                    word = word.strip()
                    if word in (g.lower() for g in graphs):
                        output.append('<tr><td align=center>')
                        output.append(embed_graph(graph[0], height=120, width=365, start=-14400, legend=True))
                        output.append('</td>')
                        output.append('<td align=center>')
                        output.append(embed_graph(graph[0], height=120, width=365, start=-172800, legend=True))
                        output.append('</td>')
                        output.append('<td align=center>')
                        output.append(embed_graph(graph[0], height=120, width=365, start=-1209600, legend=True))
                        output.append('</td></tr>')
                        gb = True
                title = title.split(' - ')[-1].strip()
                tab += '<td align=center><font size=-1>%s</font><br>%s</td>' % \
                        (title, embed_graph(graph[0], height=120))
                if not nl:
                    tab += '</tr><tr>'
                    nl = 3
                else:
                    nl -= 1
            if gb:
                output.append('<tr><td align=center>4 hour</td><td align=center>2 day</td>')
                output.append('<td align=center>2 week</td></tr>')
            output.append('</table>')
            tab += '</tr></table>'

    if len(tab):
        return (output, {'tabs': [{'header': 'Graphs', 'body': tab}]})
    else:
        return (output, {})

