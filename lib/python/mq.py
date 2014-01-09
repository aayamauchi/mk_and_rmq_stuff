#!/usr/bin/env python

import pika
import json

from time import time as unixtime

class param:
	# Do we really want this in this class? We could change the
	# client init to allow passing a param class, so that
	# subclasses with different params (including this method)
	# could be passed.

	default = {
		'connection': {
			'hostaddress': '127.0.0.1',
			'hostport': 5672,
			'virtual_host': '/',
			'username': 'guest',
			'password': 'guest',
			'blocking': True
		},
		'channel': {
			'queue': 'monitoring'
		},
		'message': {
			'content_type': 'application/json',
			'delivery_mode': 1
		}
	}
	
	def __init__(self,*args,**kwargs):
		self.data = param.default
		
		if kwargs.has_key('connection'):
			self.data['connection'].update(kwargs['connection'])

		if kwargs.has_key('channel'):
		 	self.data['channel'].update(kwargs['channel'])
		
		return None
	
	def __getitem__(self,key):
		return self.data[key]

	def get_pika_ConnectionParameters(self):
		return pika.ConnectionParameters(
			self.data['connection']['hostaddress'],
			self.data['connection']['hostport'],
			self.data['connection']['virtual_host'],
			pika.PlainCredentials(
				self.data['connection']['username'],
				self.data['connection']['password']
			)
		)

class client:

	@staticmethod
	def callback(channel,method,properties,body):
		print json.read(body)
	
	def __init__(self,*args,**kwargs):

		self.param = param(**kwargs)

		if kwargs.has_key('callback'):
			# Calls to the callback will look like a method call, but
			# will invoke like a function (ie. no instance pointer as
			# the first argument) when done this way and will override
			# the call to the staticmethod defined for this class.
			self.callback = kwargs['callback']

		## WTF is this?
		#if kwargs.has_key('metadata'):
		#	self.metadata = message_metadata(kwargs['metadata'])
		#else:
		#	self.metadata = message_metadata()

		if self.param['connection']['blocking']:
			self.connection = pika.BlockingConnection(
				self.param.get_pika_ConnectionParameters()
			)
		else:
			self.connection = pika.AsyncoreConnection(
				self.param.get_pika_ConnectionParameters()
			)

		if hasattr(self,'connection'):
			self.channel = self.connection.channel()

		if hasattr(self,'channel'):
			self.channel.queue_declare(queue=self.param['channel']['queue'])

		return None
	
	def __del__(self):
		if hasattr(self,'connection'):
			if self.connection.is_open:
				self.connection.close()
				del self.connection
	
		return self

	def pull(self,*args,**kwargs):
		# The callacke is going to have to be a function reference, which
		# is kind of a mess to get configured and passed with Python.
		# Remember that it *cannot* be a object method -- it has to either
		# be a fuction or a static class method. 

		self.channel.basic_consume(
			self.__class__.callback,
			queue=self.param['channel']['queue'],
			no_ack=True
		)
		return self
	
	def push(self,*args,**kwargs):

		message = {}

		## WTF is this?
		#if kwargs.has_key('metadata'):
		#	message['metadata'] = kwargs['metadata'].get_dict()
		#else:
		#	metadata['metadata'] = self.metadata.get_dict()
		
		if kwargs.has_key('data'):
			message['data'] = kwargs['data']
		else:
			mesage['data'] = {}

		self.channel.basic_publish(
			exchange = self.connection['hostaddress'],
			routing_key = self.param.channel['queue'],
			body = json.write(message),
			properties = pika.BasicProperties(
				content_type = 'application/json',
				delivery_mode = 1
			)
		)
		
		return self

if __name__ == '__main__':
	test_obj = client()
