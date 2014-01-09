#!/usr/bin/perl
#==============================================================================
# check_cobbler.pl
#
# Check for existence of cobbler profile on specified server.
#
# Profiles can be checked according to a profile flavor now, based on
# source (-S source) selection. This is to support different profiles in
# Khalifa and SecApps.
#
# The -p argument now accepts multiple profile types, comma separated.
# Each profile type should contain a flavor and profile name, colon separated.
#
#   flavor:Profile-name-to-monitor
#
# Examples for -p argument (all of these work):
#
#   'khalifa:RHEL-Server-5.9-Generic-Std-x86_64,secapps:RHEL-Server-5.4-x86_64'
#   'khalifa:RHEL-Server-5.9-Generic-Std-x86_64'
#   'RHEL-Server-5.9-Generic-Std-x86_64'
#
# You can skip flavor and -S for legacy mode (last example above).
#
# Mapping between source (-S) and flavor (specified in profile types):
#   source         flavor
#   ------------   -------
#   ASDB/Servers   secapps
#   Khalifa CMS    khalifa
#
# If source type and profile selection don't map then a generic flavor
# will be checked.
#
# 2013-04-12 tritu, created and provided to monops (MONOPS-1419)
# 2013-10-11 jramache, added -S (source) and cobbler flavors: khalifa, secapps
#==============================================================================
use strict;
use XMLRPC::Lite;
use Getopt::Std;

my %options=();
getopts("H:n:m:i:p:S:s", \%options);

my $cobbler_server = "$options{H}";
my $name = "$options{n}";
my $mac_address = "$options{m}";
my $ip_address = "$options{i}";
my $profile = "$options{p}";
my $source = "$options{S}";
my $serial = "$options{s}";

my $return;
my @return;
my $match;

if ( $cobbler_server eq "" ) {
	$cobbler_server = "127.0.0.1";
}

my $flavor = "generic";
if ($source =~ /khalifa/i) {
    $flavor = "khalifa";
}
elsif ($source =~ /asdb/i) {
    $flavor = "secapps";
}
my $source_flavor_matched = 0;
if ($profile =~ /,/) {
    foreach my $profile_type (split(/,/, $profile)) {
        if ($profile_type =~ /:/) {
            my @profile_item = split(/:/, $profile_type);
            if (lc($profile_item[0]) eq lc($flavor)) {
                $profile = $profile_item[1];
		$source_flavor_matched = 1;
            }
        }
    }
}
elsif ($profile =~ /:/) {
    my @profile_item = split(/:/, $profile);
    if (lc($profile_item[0]) eq lc($flavor)) {
	$profile = $profile_item[1];
	$source_flavor_matched = 1;
    }
}
if (($profile eq "") || ($profile =~ /,/) || ($profile =~ /:/)) {
    $profile = "RHEL-Server-5.4-x86_64";
    $flavor = "generic";
}
elsif (($profile ne "") && (! $source_flavor_matched) ) {
    $flavor = "user defined";
}

# Build the connection
my $xmlrpc = XMLRPC::Lite -> proxy("http://$cobbler_server/cobbler_api");

sub chk_profile () {
	my $match = 0;
	my @profiles = &get_profiles();

	foreach my $cobbler_profile (@profiles) {
		chomp($cobbler_profile);

		if ( "$profile" eq "$cobbler_profile" ) {
			$match = 1;
			last;
		}
	}
	return $match;
}

sub get_profiles () {
	my $connection_status = eval { $xmlrpc->get_profiles(); };
	my $error_captured = "$@";

	if ( $error_captured =~ m/[500|503]/ ) {
		print "CRITICAL. $error_captured";
		exit 2;
	}

	my $list = $xmlrpc->get_profiles();
	my $params = $list->valueof('//params/param');

	foreach my $value(@$params) {
		my $return = $value->{'name'};
		push (@return, $return);
	}

	return(@return);
}

my $chk_pro = &chk_profile();

if ($chk_pro == 1 ) {
	print "OK - Found Profile: $profile on $cobbler_server (profile flavor: ${flavor})\n";
        exit 0;
}
else {
	print "CRITICAL - Profile $profile is not found on $cobbler_server (profile flavor: ${flavor})!\n";
	exit 2;
}
