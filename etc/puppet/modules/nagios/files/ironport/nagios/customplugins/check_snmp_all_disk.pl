#!/usr/local/bin/perl --
# 
# This script checks for disk space via SNMP on the NetApp.
# Contributed by IronPort Inc. to GroundWork Open Source, Inc. 
# for public distribution.  
# Original Author:
# Tim Spencer <tspencer@ironport.com>
# Wed Jun  8 20:39:18 PDT 2005
#
# Usage:
#        command_line    $USER1$/check_snmp_disk.pl -H $HOSTADDRESS$ -C $ARG1$ -m $ARG2$ -w $ARG3$ -c $ARG4$
# Where:
#       $USER1$ = path to Nagios(R) plugin directory
#				$HOSTADDRESS$ = IP of the host to be tested
#				$ARG1$ = SNMP Read string
#				$ARG2$ = Warning threshold in percent used
#				$ARG3$ = Critical threshold in percent used
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
# Wed Jan 7 2009 - Modified for 'check all disks' logic. - Mike Lindsey
#
use lib "/usr/local/nagios/libexec";
require 'utils.pm';
use Getopt::Long;
use vars qw($opt_H $opt_C $opt_w $opt_c $opt_D $opt_V $opt_h );
use vars qw($PROGNAME);
use lib ".";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
use strict;

sub print_help ();
sub print_usage ();

my $PROGNAME = "check_all_snmp_disk";
my ($name, $i, $critical, $warn, $name, $host, $community, $opt_V, $opt_D, $opt_h);

Getopt::Long::Configure('bundling');
my $status = GetOptions
        ("V"   => \$opt_V, "Version"         => \$opt_V,
         "H=s" => \$host, "host=s"  => \$host,
         "C=s" => \$community, "community=s"  => \$community,
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
	$warn = 85;
}

my $index = 0;

my $baseoid = ".1.3.6.1.4.1.2021.9.1";
my $oid;
my $percentfull;
my $outstr;


my $okstr = "";
my $warnstr = "";
my $critstr = "";
# iterate through the mountpoints until we run out of them.
for($i=1;$i < 50; $i++) {
	$oid = "$baseoid.2.$i";
	open(GET,"/usr/bin/snmpget -r 2 -t 10 -On -v 2c -c $community $host $oid 2>&1|");

	$name = "";
	while(<GET>) {
		next unless /STRING:/;
		chomp;
		split;
		$name = $_[3];
		$name =~ s/"//g;

		$index = $i;
                # get the percent full of the mountpoint we are searching for
		$oid = "$baseoid.9.$index";
		open(GET2,"/usr/bin/snmpget -r 2 -t 10 -v 2c -c $community $host $oid 2>&1|");
		while(<GET2>) {
			next unless /INTEGER:/;
			chomp;
			split;
			$percentfull = $_[3];
		}
		close(GET2);
		if ($percentfull > $critical) {
			$critstr .= " $name at $percentfull%";
		} elsif ($percentfull > $warn) {
			$warnstr .= " $name at $percentfull%";
		} else {
			$okstr .= " $name at $percentfull%";
		}
	}
	close(GET);

	# if we've run out of mountpoints, cause the loop to exit.
	if($name eq "") {
		$i = 256;
	}
}

if ($critstr ne "") {
    $outstr = "CRITICAL:$critstr";
    if ($warnstr ne "") {
    	$outstr .= " WARNING:$warnstr";
    }
    print "$outstr\n";
    exit(2);
}
if ($warnstr ne "") {
	print "WARNING:$warnstr.\n";
	exit(1);
}
if ($okstr eq "") {
	print "UNKNOWN: No partitions found!\n";
	exit(3);
}

print "OK:$okstr.\n";
exit(0);
# Usage sub
sub print_usage () {
        print "Usage: 
        command_line    \$USER1\$/check_all_snmp_disk.pl -H \$HOSTADDRESS\$ -C \$ARG1\$ -w \$ARG2\$ -c \$ARG3\$
 Where:
       \$USER1\$ = path to Nagios(R) plugin directory
				\$HOSTADDRESS\$ = IP of the host to be tested
				\$ARG1\$ = SNMP Read string
				\$ARG2\$ = Warning threshold in percent used
				\$ARG3\$ = Critical threshold in percent used
	[-h] (help) \n";
}


# Help sub
sub print_help () {
        print "Copyright (c) 2007 GroundWork Open Source, Inc.

This script checks for disk space on all partitions via SNMP
";
        print_usage();
        print "
This plugin will return OK if the specified mount point is below critical and warning thresholds of actual disk space used.
Thresholds are in percent full. Make sure critical threshold is above warning. 
Default Warning is 85, critical is 90. \n";
}

