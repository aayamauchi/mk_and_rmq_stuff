#!/usr/local/bin/perl --
# 
# This script checks for Inodes via SNMP on the NetApp.
# Contributed by IronPort Inc. to GroundWork Open Source, Inc. 
# for public distribution.  
# Original Author:
# Tim Spencer <tspencer@ironport.com>
# Wed Jun  8 20:39:18 PDT 2005
#
# Usage:
#        command_line    $USER1$/checkNetAppDiskInodes.pl -H $HOSTADDRESS$ -C $ARG1$ -m $ARG2$ -w $ARG3$ -c $ARG4$
# Where:
#       $USER1$ = path to Nagios(R) plugin directory
#				$HOSTADDRESS$ = IP of the netapp to be tested
#				$ARG1$ = SNMP Read string
#				$ARG2$ = List of mount points
#				$ARG3$ = Warning threshold in percent used
#				$ARG4$ = Critical threshold in percent used
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
#	Mon March 12th, 2007:
#	Revised to add warn and crit as args.
# Added performance data. 
# Added GroundWork attribution, and other beautification

# Default warning and critical thresholds
use lib "/usr/local/nagios/libexec";
require 'utils.pm';
use Getopt::Long;
use vars qw($opt_H $opt_C $opt_w $opt_c $opt_D $opt_V $opt_h );
use vars qw($PROGNAME);
use lib ".";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);

sub print_help ();
sub print_usage ();

$PROGNAME = "checkNetAppDiskSpace";

Getopt::Long::Configure('bundling');
my $status = GetOptions
        ("V"   => \$opt_V, "Version"         => \$opt_V,
         "H=s" => \$host, "host=s"  => \$host,
         "C=s" => \$community, "community=s"  => \$community,
         "m=s" => \$mountpoint, "mountpoint=s"  => \$mountpoint,
         "w=s" => \$warn, "warning=s"  => \$warn,
         "c=s" => \$critical, "critical=s"  => \$critical,
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

# Default warning and critical thresholds
if (!$critical) {
    $critical = 90;
}
if (!$warn) {
    $warn = 80;
}

$index = 0;

# iterate through the mountpoints until we run out of them.
for($i=1;$i < 100; $i++) {
	$oid = ".1.3.6.1.4.1.789.1.5.4.1.2.$i";
	open(GET,"/usr/bin/snmpget -r 2 -t 15 -v1 -c $community $host $oid 2>&1|");

	$name = "";
	while(<GET>) {
		next unless /STRING:/;
		chomp;
		split;
		$name = $_[3];
		$name =~ s/"//g;

		# if the mountpoint matches the argument, then grab the index
		if($name eq $mountpoint) {
			$index = $i;
		}
	}
	close(GET);

	# if we've run out of mountpoints, cause the loop to exit.
	if($name eq "") {
		$i = 256;
	}
}

# make sure we found a real index.
if($index == 0) {
	print "UNKNOWN - $mountpoint not found on $host\n";
	exit 3;
}

# get the percent full of the mountpoint we are searching for
$oid = ".1.3.6.1.4.1.789.1.5.4.1.9.$index";
open(GET,"/usr/bin/snmpget -r 2 -t 15 -v1 -c $community $host $oid 2>&1|");
while(<GET>) {
	next unless /INTEGER:/;
	chomp;
	split;
	$percentfull = $_[3];
}

#print "percent full of $mountpoint on $host is $percentfull\n";
if($percentfull > $critical ) {
	print "CRITICAL - $mountpoint is at $percentfull% of inode capacity.| inode_pct=$percentfull;$warn;$critical;;\n";
	exit 2;
}
if($percentfull > $warn ) {
	print "WARNING - $mountpoint is at $percentfull% of inode capacity.| inode_pct=$percentfull;$warn;$critical;;\n";
	exit 1;
}

print "OK - $mountpoint is at $percentfull% of inode capacity.| inode_pct=$percentfull;$warn;$critical;;\n";
exit 0;

# Usage sub
sub print_usage () {
        print "Usage:
        command_line    \$USER1\$/checkNetAppInodes.pl -H \$HOSTADDRESS\$ -C \$ARG1\$ -m \$ARG2\$ -w \$ARG3\$ -c \$ARG4\$
 Where:
       \$USER1\$ = path to Nagios(R) plugin directory
                \$HOSTADDRESS\$ = IP of the netapp to be tested
                \$ARG1\$ = SNMP Read string
                \$ARG2\$ = List of mount points
                \$ARG3\$ = Warning threshold in percent used
                \$ARG4\$ = Critical threshold in percent used
    [-h] (help) \n";
}


# Help sub
sub print_help () {
        print "Copyright (c) 2007 GroundWork Open Source, Inc.

This script checks for disk space via SNMP on the NetApp.
";
        print_usage();
        print "
This plugin will return OK if the specified mount point is below critical and warning thresholds of inodes used.
Thresholds are in percent full. Make sure critical threshold is above warning.
Default Warning is 80, critical is 90. \n";
}

