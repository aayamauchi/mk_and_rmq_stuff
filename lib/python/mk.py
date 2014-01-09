#!/usr/bin/env python

# Note: all query returns from MK Livestatus will be JSON
# and converted to data structures for storage by the
# class instance.  Output format specifications in the
# client class pertain to how the results are returned by
# a given class method, not MK Livestatus.  In particular,
# the default data structure will have the connection
# information added an will be converted to a list of
# records, rather than the list of list tabular format
# used as the JSON output format by MK Livestatus.

# The client class should be the only thing that needs to
# be imported from this module.  Use the following:
# from mk import client as mk_client

import socket
import json

from time import time as unixtime

class param:
	# Adding a class to handle the setting of defaults really
	# cleans up the main class doing the work.


# Change this for a sec so we can see if this works for the
# standard MK Livestatus UNIX socket on the local filesystem.
#			{
#				'type': 'tcp',
#				'host': socket.getfqdn(),
#				'port': 6557,
#				'persistent': True
#			}
#			{
#				'type': 'unix',
#				'host': socket.getfqdn(),
#				'socket': '/var/nagios/rw/live',
#				'persistent': True
#			}

	default = {
		'connections': [
			{
				'type': 'tcp',
				'host': '127.0.0.1',
				'socket': '/usr/local/nagios/var/rw/live',
				'port': 6557,
				'persistent': True
			}
		],
		'output': {
			'format': 'data',
			'type': 'records',
			'timestamp': True
		},
		'query': {
			'Columns': [],
			'Filter': [],
			'Limit': 0,
			'AddLines': [
				'ColumnHeaders: on',
				'OutputFormat: json',
				'KeepAlive: on'
			]
		},
		'history': {
			'limit': False,
			'max': 10
		}
	}

# Use this as an AddLine if we want the connection status in the first
# 16 bytes.  However, a handler must be written to deal with it.
#				'ResponseHeader: fixed16'

	def __init__(self,*args,**kwargs):
		self.data = param.default

		for k in kwargs.keys():
			self.data[k].update(kwargs[k])

		return None

	def __getitem__(self,key):
		return self.data[key]

	def __repr__(self):
		return json.write(self.data)
	
	def __del__(self):
		try:
			self.data.close()
		except:
			pass
		return self

class connection:
	# The socket module is a function library, not a class.  Trying
	# to get this to act more like a class -- especially to abstract
	# needed parameters as class data and reimplement the functions
	# as methods with keyed arguments, rather than the underlying
	# functions which use positional arguments.
	
	def __init__(self,*args,**kwargs):

		self.param = kwargs

		if self.param['type'] == 'unix':
			self.data = socket.socket(
				socket.AF_UNIX,
				socket.SOCK_STREAM
			)

			self.param['uri'] = 'unix:%s:%s' % ( self.param['host'],self.param['socket'])
			self.param['args'] = self.param['socket']
		else:
			self.data = socket.socket(
				socket.AF_INET,
				socket.SOCK_STREAM
			)

			self.param['uri'] = 'tcp:%s:%s' % ( self.param['host'],self.param['port'])
			self.param['args'] = ( self.param['host'], self.param['port'] )
		
			if self.param['persistent']:
				self.data.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
				self.data.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE, 1)
				self.data.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, 1)
				self.data.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPCNT, 5)

		return None
	
	def connect(self):
		try:
			self.data.connect(self.param['args'])
		except:
			pass
		return self
	
	def send(self,message):
		self.data.send(message)
		return self
	
	def receive(self,buffer_size=4096):
		ret_val = ''
		while True:
			tmp_val = self.data.recv(buffer_size)
			if tmp_val == '':
				break
			else:
				ret_val += tmp_val
		self.close()
		return ret_val

	def shutdown(self):
		self.data.shutdown(socket.SHUT_WR)
		return self
	
	def close(self):
		try:
			self.data.close()
		except:
			pass

		return self

	def session(self,message):
		# Take a text message, send it to the socket, return whatever
		# comes back in a completely generic way.

		while True:
			try:
				self.send(message)
			except:
				self.connect()
			else:
				return self.shutdown().receive()

class query:

	def __init__(self,*args,**kwargs):
		self.data = kwargs

		return None
	
	def __setitem__(self,key,value):
		self.data[key] = value
		return self
	
	def __getitem__(self,key):
		return self.data[key]

	def __repr__(self):
		return self.lql()
	
	def lql(self):
		lines = [ 'GET %s' % self.data['Table'] ]
		if self.data.has_key('Columns'):
			if len(self.data['Columns']) > 0:
				lines.append('Columns: %s' % (' '.join(self.data['Columns'])))
		if self.data.has_key('Limit'):
			if self.data['Limit'] > 0:
				lines.append('Limit: %u' % ( self.data['Limit'] ))
		if self.data.has_key('Filter'):
			if len(self['Filter']) > 0:
				# Do this as raw text, for now. 
				lines += self.data['Filter']

		if self.data.has_key('AddLines'):
			if len(self.data['AddLines']) > 0:
				lines += self.data['AddLines']

		return "\n".join(lines) + "\n\n"
	
class result:

	def __init__(self,*args,**kwargs):
	
		if kwargs.has_key('param'):
			self.param = kwargs['param']
			del kwargs['param']
		else:
			self.param = { 'format':'records' }

		if len(kwargs.keys()) > 0:
			self.set(**kwargs)

		return None

	def append(self,*args,**kwargs):

		if len(args) > 0:
			input_data = dict([('%s,%u' % ('default:unknown:unknown',unixtime),args[1])])
		else:
			input_data = kwargs

		# With this, we have a structure like this:
		# { 'connection': [ [ <result table rows> ] ] }
		if self.param['format'] == 'table':
			# A list of lists representing a table, with a header
			# row as the first list element and a final column
			# "_connection" added for the connection string.
			for k in sorted(input_data.keys()):
				if len(self.data) == 0:
					# Keep the column names for the metadata distinct
					# by prepending with a '_'.
					self.data += input_data[k][0] + ['_connection', '_timestamp' ]
				self.data += [ r + k.split(',')  for r in input_data[k][1:] ]
		else:
			for k in sorted(input_data.keys()):
				self.data += [
					dict(zip(input_data[k][0] + ['_connection','_timestamp'], r + k.split(',')))
					for r in input_data[k][1:]
				]

		return self

	def set(self,*args,**kwargs):
		self.data = []
		return self.append(*args,**kwargs)

	def get(self):
		# Using this method returns the data structure (not a
		# JSON string representation).
		return self.data

	def __repr__(self):
		# Any requests for a string reprentation returns a the
		# JSON representation of the class data.
		return json.write(self.data)

class client:
	# The publicly available Python libs for this are pretty
	# underdeveloped.  Mostly looking for something that wiLl
	# post-process JSON outputs into something useable.  May
	# have to revert to the Perl libs I wrote in the past.

	def __init__(self,*args,**kwargs):
		self.param = param(**kwargs)

		self.connections = [ connection(**s) for s in self.param['connections'] ]

		# Store the history.
		self.history = {
			'queries': [],
			'results': []
		}
		
		return None
	
	def query(self,*args,**kwargs):
	
		output_param = self.param['output']
		if kwargs.has_key('output'):
			output_param.update(kwargs['output'])
			del kwargs['output']
		
		query_param = self.param['query']
		if len(kwargs.keys()) > 0:
			query_param.update(kwargs)

		self.history['queries'].append(query(**query_param))

		# The Python JSON libraries are mis-communicating with
		# the MK Livestatus JSON output -- eval is the only thing
		# that seems to work on input.
		self.history['results'].append(
			result(
				**dict(
					[
						(
							'%s,%u' % ( c.param['uri'], unixtime() ),
							eval( c.session(self.history['queries'][-1].lql()) )
						)
						for c in self.connections
					] + [ ( 'param', output_param ) ]
				)
			)
		)

		# If the max number of history elements is limited, pop
		# the first elements if we're over.
		if self.param['history']['limit']:
			for key in self.history.keys():
				if len(self.history[key]) > self.param['history']['max']:
					self.history[key].pop(0)

		return self
	
	def __repr__(self):
		return json.write(
			[
				{
					'query': self.history['queries'][i].lql(),
					'result': self.history['results'][i].get()
				}
				for i in range(0,len(self.history['results']))
			]
		)

	def __getitem__(self,key=-1):
		# Return a struct with the query and results, as data.
		# Default to the last query run.

		return {
			'query': self.history['queries'][key].lql(),
			'result': self.history['results'][key].get()
		}

if __name__ == '__main__':
	# There is something really messed up with trying to reuse a connection.
	test_obj = client()
	#test_obj.query(Table='hosts',Columns=['name'])
	#test_obj.query(Table='hosts',Limit=2)
	test_obj.query(Table='log',Filter=[ 'Filter: time > %u' %(unixtime() - 60*60) ],Limit=1,output={'type':'table'})
	#print test_obj[-2]
	print test_obj[-1]
