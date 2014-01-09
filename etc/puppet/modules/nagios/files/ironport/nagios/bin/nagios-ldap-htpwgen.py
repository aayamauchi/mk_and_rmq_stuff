#!/usr/bin/env python26

def split_groups(groups):
    """Used to split up a comma delimited string into a list."""
    return [group.strip() for group in groups.split(',')]

def sort_uids(a, b):
    if int(a['uidNumber'][0]) > int(b['uidNumber'][0]):
        return 1
    if int(a['uidNumber'][0]) < int(b['uidNumber'][0]):
        return -1
    if int(a['uidNumber'][0]) == int(b['uidNumber'][0]):
        return 0

if __name__ == '__main__':
    import ldap
    import traceback
    import sys
    import re
    import ConfigParser
    import socket
    import os

    try:
        config_file = sys.argv[1]
    except IndexError:
        config_file = "/usr/local/ironport/nagios/var/nagios-centralizedauth.cfg"

    config = ConfigParser.ConfigParser()

    # Load the config file, if it fails to load exit.
    config.read(config_file)
    if len(config.sections()) == 0:
        print "Error: Unable to open %s." % (config_file)
        sys.exit(1)

    ldap_session = ldap.initialize(ldap.get_option(ldap.OPT_URI))
    ldap_session.simple_bind_s(config.get('DEFAULT', 'binddn'),
        config.get('DEFAULT', 'bindpw'))

    # Get all the data from all the sections that match this hosts name.
    imagename = '/etc/image_name'
    if os.path.isfile(imagename):
        hostname = open(imagename).read().rstrip()
    else:
        hostname = socket.gethostname()
    allowedgroups = {}
    defaultgroups = split_groups(config.get('DEFAULT', 'defaultgroups'))
    for group in defaultgroups:
        allowedgroups[group] = True
    disallowedgroups = {}

    for section in config.sections():
        regexp = re.compile(section)
        if not regexp.match(hostname) == None:
            if config.has_option(section, 'allowedgroups'):
                for group in split_groups(config.get(section, 'allowedgroups')):
                    allowedgroups[group] = True
            if config.has_option(section, 'disallowedgroups'):
                for group in split_groups(config.get(section, 'disallowedgroups')):
                    disallowedgroups[group] = True

    # Remove any groups that are in the disallowed list
    for group in disallowedgroups.keys():
        if allowedgroups.has_key(group):
            del allowedgroups[group]

    # Get all the users in all of the allowed groups, making sure that each
    # user only shows up once.
    query_string = "(&(objectclass=groupOfUniqueNames)(|"
    for group in allowedgroups.keys():
        query_string += "(cn=%s)" % (group)
    query_string += "))"

    user_dn_dict = {}

    results = ldap_session.search_s(config.get('DEFAULT', 'grouplocation'),
        ldap.SCOPE_SUBTREE, query_string)

    if results == None:
        sys.stderr.write("Error: No groups found.\n")
        sys.exit(1)
    else:
        for dn, values in results:
            for user_dn in values['uniqueMember']:
                user_dn_dict[user_dn] = True

    user_dn_list = user_dn_dict.keys()

    # Build a list of uids
    query_string = "(|"
    for dn in user_dn_list:
        uid = re.search(r'(uid=.*?),', dn).group(1)
        query_string += "(%s)" % (uid)
    query_string += ")"

    # Get user info
    results = ldap_session.search_s(config.get('DEFAULT', 'corporaterootdn'),
        ldap.SCOPE_SUBTREE, query_string)

    # Read in users, make sure there are no duplicate users:  first match wins
    normal_users = []
    normal_map = {}
    if not results == None:
        for dn, values in results:
            login = values['uid'][0]
            if login not in normal_map:
                normal_map[login] = True
                normal_users.append(values)
    else:
        sys.stderr.write("Error: Corporate uids not found.\n")
        sys.exit(1)

    # Sort the users list by uid - because I'm anal
    normal_users.sort(sort_uids)

    # remove users that might mask system users
    normal_map = {}
    for user in normal_users:
        login = user['uid'][0]
        normal_map[login] = user
    #for user in users:
    #    login = user['uid'][0]
#	if login in normal_map:
 #           normal_users.remove(user)

    # Merge the system and user lists
    users = normal_users

    # Print out the user table
    for user in users:
        login = user['uid'][0]
        try:
            password = user['userPassword'][0][7:]
        except KeyError:
            password = "*"
        uid = user['uidNumber'][0]
        gid = user['gidNumber'][0]
        gecos = user['gecos'][0]
        homedir = user['homeDirectory'][0]
        try:
            shell = user['loginShell'][0]
        except KeyError:
            shell = "/bin/false"

        # master.passwd format
	# re-arrange as needed in .sh for other platforms
	if '*' not in password:
	    print "%s:%s" % (login, password)

    ldap_session.unbind_s()
