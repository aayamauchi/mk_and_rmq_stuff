#!/usr/local/bin/perl --
# 
# This script checks license status via SNMP on the NetApp.
# Original Author:
# Tim Spencer <tspencer@ironport.com>
# Wed Jun  8 20:39:18 PDT 2005
#
# Usage:
#        command_line    $USER1$/checkNetAppLicenses.pl -H $HOSTADDRESS$ -C $ARG1$
# Where:
#       $USER1$ = path to Nagios(R) plugin directory
#				$HOSTADDRESS$ = IP of the netapp to be tested
#				$ARG1$ = SNMP Read string
#				$ARG2$ = License Key to test
#
# 
# Copyright (c) 2007 GroundWork Open Source, Inc.
# 
# This plugin is FREE SOFTWARE. No warranty of any kind is implied or granted. 
# You may use this software under the terms of the GNU General Public License only.
# See http://www.gnu.org/copyleft/gpl.html and usage sections of this code.
#
# Changelog: 
# Wed Jun  8 20:39:18 PDT 2005 - original version 
#	Fri Jun  1 15:51:36 PDT 2007 - Modified to deal with licenses
#	by Emily Gladstone Cole <emily@ironport.com>

# Default warning and critical thresholds
use lib "/usr/local/nagios/libexec";
require 'utils.pm';
use Getopt::Long;
use vars qw($opt_H $opt_C $opt_D $opt_V $opt_h );
use vars qw($PROGNAME);
use lib ".";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);

sub print_help ();
sub print_usage ();

$PROGNAME = "checkNetAppLicenses";

Getopt::Long::Configure('bundling');
my $status = GetOptions
        ("V"   => \$opt_V, "Version"         => \$opt_V,
         "H=s" => \$host, "host=s"  => \$host,
         "C=s" => \$community, "community=s"  => \$community,
         "k=s" => \$licensekey, "licensekey=s"  => \$licensekey,
         "D"   => \$opt_D, "debug"            => \$opt_D,
         "h"   => \$opt_h, "help"            => \$opt_h);

if ($status == 0)
{
        print_usage() ;
        exit $ERRORS{'OK'};
}

if ($opt_V) {
        print_revision($PROGNAME,'$Revision: #1 $'); #'
        exit $ERRORS{'OK'};
}
# If all we are doing is printing out help, do that and exit.

if ($opt_h) {print_help(); exit $ERRORS{'OK'};}

$critical = 1;
$success = 2;

my %traps = (
	NFS => ".1.3.6.1.4.1.789.1.3.3.1.0",
	FCP => ".1.3.6.1.4.1.789.1.17.1.0",
	ISCSI => ".1.3.6.1.4.1.789.1.17.2.0",
	SnapMirror => ".1.3.6.1.4.1.789.1.9.19.0",
	SnapVaultPrimary => ".1.3.6.1.4.1.789.1.19.9.0",
	SnapVaultSecondary => ".1.3.6.1.4.1.789.1.19.10.0",
	Cluster => ".1.3.6.1.4.1.789.1.2.3.1.0",
	);

$index = 0;

# if they didn't specify a vaild trap key we should exit

foreach (keys %traps) {
	if ( $licensekey eq $_ ) { # we have a valid argument
		$index = 1;
		$oid = $traps{"$licensekey"};
	}
}

if ( $index == 0 ) {
	print_help() ;
	exit 0;
}

open(GET,"/usr/bin/snmpget -r 2 -t 15 -v1 -c $community $host $oid 2>&1|");
while(<GET>) {
	next unless /INTEGER:/;
	chomp;
	split;
	$licensed = $_[3];
}

if ( $licensed == $critical ) {
	print "CRITICAL - $licensekey is not licensed.\n";
	exit 2;
} elsif ( $ licensed != $success ) {
	print "WARNING - $licensekey value unexpected.\n";
	exit 1;
}

print "OK - $licensekey is licensed.\n";
exit 0;

# Usage sub
sub print_usage () {
        print "Usage:
        command_line    \$USER1\$/checkNetAppLicenses.pl -H \$HOSTADDRESS\$ -C \$ARG1\$ -k \$ARG2\$
 Where:
       \$USER1\$ = path to Nagios(R) plugin directory
                \$HOSTADDRESS\$ = IP of the netapp to be tested
                \$ARG1\$ = SNMP Read string
                \$ARG2\$ = License key to check
    [-h] (help) \n";
}


# Help sub
sub print_help () {
        print "
This script checks license status via SNMP on the NetApp.
";
        print_usage();
        print "
This plugin will return OK if the specified license is valid.
\n";
}

