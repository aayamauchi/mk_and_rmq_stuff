#!/usr/local/bin/perl --
# 
# This script checks for Failed Disks via SNMP on the NetApp.
# Original Author:
# Tim Spencer <tspencer@ironport.com>
# Wed Jun  8 20:39:18 PDT 2005
#
# Usage:
#        command_line    $USER1$/checkNetAppFailedDisk.pl -H $HOSTADDRESS$ -C $ARG1$ [-k $ARG2$]
# Where:
#       $USER1$ = path to Nagios(R) plugin directory
#				$HOSTADDRESS$ = IP of the netapp to be tested
#				$ARG1$ = SNMP Read string
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
use vars qw($opt_H $opt_C $opt_w $opt_c $opt_D $opt_V $opt_h );
use vars qw($PROGNAME);
use lib ".";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);

sub print_help ();
sub print_usage ();

$PROGNAME = "checkNetAppFailedDisk";

# set defaults
my $warn = 1;
my $critical = 1;
my $ticket_priority = "[##i3##][##u3##]";
my $oid = ".1.3.6.1.4.1.789.1.6.4.7.0";

# retrieve options
Getopt::Long::Configure('bundling');
my $status = GetOptions
        ("V"   => \$opt_V, "Version"         => \$opt_V,
         "H=s" => \$host, "host=s"  => \$host,
         "C=s" => \$community, "community=s"  => \$community,
         "w=s" => \$warn, "warning=s"  => \$warn,
         "c=s" => \$critical, "critical=s"  => \$critical,
         "f=s" => \$knownfailed, "knownfailed=s"  => \$knownfailed,
         "D"   => \$opt_D, "debug"            => \$opt_D,
         "h"   => \$opt_h, "help"            => \$opt_h);

if ($status == 0) {
        print_usage() ;
        exit $ERRORS{'OK'};
}

if ($opt_V) {
        print_revision($PROGNAME,'$Revision: #1 $'); #'
        exit $ERRORS{'OK'};
}

# If all we are doing is printing out help, do that and exit.
if ($opt_h) {
    print_help();
    exit $ERRORS{'OK'};
}

if ($knownfailed) {
        $warn = $warn + $knownfailed;
        $critical = $critical + $knownfailed;
}

open(GET,"/usr/bin/snmpget -v1 -r 2 -t 15 -c $community $host $oid 2>&1|");
while(<GET>) {
	next unless /INTEGER:/;
	chomp;
	split;
	$faileddisks = $_[3];
}

#print "percent full of $mountpoint on $host is $percentfull\n";

if ($faileddisks >= 2) {
    # multiple disk failures warrant higher ticket priority
    $ticket_priority = "[##i2##][##u2##]";
}

if($faileddisks >= $critical ) {
	print "CRITICAL - $host has $faileddisks failed disks $ticket_priority| failed_disks=$faileddisks;$warn;$critical;;\n";
	exit 2;
}
if($faileddisks >= $warn ) {
	print "WARNING - $host has $faileddisks failed disks $ticket_priority| failed_disks=$faileddisks;$warn;$critical;;\n";
	exit 1;
}

print "OK - $host has $faileddisks failed disks.| failed_disks=$faileddisks;$warn;$critical;;\n";
exit 0;

# Usage sub
sub print_usage () {
        print "Usage:
        command_line  \$USER5\$/checkNetAppFailedDisk.pl -H \$HOSTADDRESS\$ -C '\$USER7\$' [-f \$ARG1\$] [-w \$ARG2\$] [-c \$ARG3\$]
 Where:
       \$USER5\$ = path to ironport nagios custom plugins directory
                \$HOSTADDRESS\$ = IP of the netapp to be tested
                \$USER7\$ = SNMP community read string
                \$ARG1\$ = Number of known failed disks
                \$ARG2\$ = Warning threshold on number of failed disks
                \$ARG3\$ = Critical threshold on number of failed disks
    [-h] (help) \n";
}


# Help sub
sub print_help () {
        print "
This script checks for failed disks via SNMP on the NetApp.
";
        print_usage();
        print "
This plugin will return OK if there are no failed disks.
\n";
}

