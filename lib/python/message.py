#!/usr/bin/env python

# Want to be able to add envelope to messages with some uniform keys
# and arguments.
from time import time as unixtime
from socket import getfqdn as hostname
from getpass import getuser as username

import json

class envelope:

	default = {
		'hostname': hostname(),
		'username': username()
	}

	# By default, assume the username matches the application name.
	default['application'] = default['username']

	def __init__(self,*args,**kwargs):
		self.data = envelope.default
		if len(kwargs) > 0:
			self.data.update(kwargs)

		return None
	
	def __repr__(self):
		return json.write(self.__call__())
	
	def __call__(self,*args,**kwargs):
		ret_val = self.data
		ret_val.update({'timestamp': unixtime()})
		if len(kwargs) > 0:
			ret_val.update(kwargs)
		return ret_val
	
	def __getitem__(self,key):
		if key == 'timestamp':
			return unixtime()
		else:
			return self.data[key]

class message:
	def __init__(self,*args,**kwargs):
		if kwargs.has_key('envelope'):
			self.envelope = envelope(**kwargs['envelope'])
			del kwargs['envelope']
		else:
			self.envelope = envelope()

		self.data = kwargs
		
		return None

	def __call__(self,*args,**kwargs):
		return {'envelope': self.envelope(), 'message': self.data }
	
	def __repr__(self):
		return json.write(self.__call__())
	
	def __getitem__(self,key):	
		if key = 'envelope':
			return self.envelope()
		else:
			return self.data

if __name__ == '__main__':
	test_obj = message()
