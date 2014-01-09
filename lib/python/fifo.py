#!/usr/bin/env python

import os

class fifo:

	# Static class defaults.  Probably should be here for a live installation.
	param = {
		'file_name': '/var/tmp/fifo'
	}

	def __init__(self,*args,**kwargs):
		self.param = fifo.param
		if len(kwargs.keys()) > 0:
			self.param.update(kwargs)
			# In general, the default isn't going to be very useful.
			# Don't create or open the fifo unless kwargs are passed.
			self.open()
		return None

	def open(self,*args,**kwargs):
		if len(kwargs.keys()) > 0:
			self.param.update(kwargs)

		os.mkfifo(self.param['file_name'])
		self.connection = open(self.param['file_name'])

		return self
		
	def __del__(self):
		try:
			os.unlink(self.param['file_name'])
		except:
			pass
		return self

	def read(self,*args,**kwargs):
		return self.connection.read(*args,**kwargs)
	
	def readline(self,*args,**kwargs):
		return self.connection.readline(*args,**kwargs)
	

if __name__ == '__main__':
	test_obj = fifo()
	
