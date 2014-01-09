#!/usr/bin/env python

import signal
import sys

from time import sleep

class daemon:
	# No parameters at this point -- traps SIGINT.

	@staticmethod
	def worker(*args,**kwargs):
		# Override this in a subclass, if needed.  If implemented as
		# a method, make sure it strips the object pointer, if needed.
		return True

	@staticmethod
	def signal_handler(signal, frame):
		# Override this in a subclass, if needed.  If implemented as
		# a method, make sure it strips the object pointer, if needed.
		'Received <CTRL>+C.  Exiting.'
		sys.exit(0)

	def __init__(self,*args,**kwargs):

	 	if kwargs.has_key('worker'):
			self.worker = kwargs['worker']

		if kwargs.has_key('signal_handler'):
			self.signal_handler = kwargs['signal_handler']

		if kwargs.has_key('sleep'):
			self.sleep = kwargs['sleep']

		signal.signal(signal.SIGINT, self.signal_handler)

		while self.worker():
			if self.__dict__.has_key('sleep'):
				sleep(self.sleep)
		
		return None

if __name__ == '__main__':

	def daemon_worker(*args,**kwargs):

		# This must return a boolean.
		try:
			print "'Ere I am, JH"
		except:
			return False
		else:
			return True

	test_obj = daemon(worker=daemon_worker,sleep=10)
