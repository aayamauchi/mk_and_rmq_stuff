#!/usr/bin/python26

import optparse

class MissingRequiredArgument(Exception):
    def __init__(self, argument):
        self.argument = argument

    def __str__(self):
        return "Missing required argument '%s'." % (str(self.argument),)

class OptionManager(optparse.OptionParser):
    """An extension to optparse for setting up required arguments for a """ \
            """command."""
    def __init__(self, required_args=None, *args, **kwargs):
        if not kwargs.get('usage', None):
            self.usage = "usage: %prog [options]"
            if required_args:
                self.usage += " %s" % (' '.join(required_args),)
                self.required_args = required_args
            else:
                self.required_args = None
            optparse.OptionParser.__init__(self, usage=self.usage, *args,
                    **kwargs)

    def parse_options(self):
        """Parses the options and arguments given on the command line and """ \
                """sets self.options to the parsed options, and self.args """ \
                """to a dictionary with a key of the argument name and """ \
                """a value of the value of the argument."""
        (self.options, args) = self.parse_args()
        arg_dict = None
        if self.required_args:
            arg_dict = dict()
            i = 0
            try:
                # Loop through args using required_args to make sure that all
                # the required arguments exist.
                while i < len(self.required_args):
                    arg_name = self.required_args[i]
                    arg_dict[arg_name] = args[i]
                    i += 1
            except IndexError:
                raise MissingRequiredArgument("%s" % (arg_name,))
        self.args = arg_dict
