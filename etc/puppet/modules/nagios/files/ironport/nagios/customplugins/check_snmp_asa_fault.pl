#!/bin/env perl
# This is a Nagios Plugin destined to check the status of Cisco ASA failover peers.
# Author Tytus Kurek ,  October 2012
# License: freeware
# Small fixes Vad Mashkov vmashkov@cisco.com
use strict;
use vars qw($community $HOST);
use Getopt::Long;
use Pod::Usage;
use Net::SNMP;
use Socket;

# Subroutines execution

getParameters ();
checkFailoverStatus ();

# Subroutines definition

sub checkFailoverStatus ()	# Checks ASA failover status
{
    my $IP = undef;
    if ($HOST !~ m/^\d+\.\d+\.\d+\.\d+$/) {
        my $packed_ip = gethostbyname($HOST) or die "Can't resolve $HOST: $!\n";
        if (defined $packed_ip) {
            $IP = inet_ntoa($packed_ip);
            }
        } else {
            $IP = $HOST;
        }

	my $interfaceOID = '.3.4';
	my $primaryOID = '.3.6';
	my $secondaryOID = '.3.7';
	my $OID = '1.3.6.1.4.1.9.9.147.1.2.1.1.1';
	my $version = '2c';

	my $command = "/usr/bin/snmpwalk -v $version -c $community $IP $OID 2>&1";
	my $result = `$command`;

	if ($result =~ m/^Timeout.*$/)
	{
		my $output = "UNKNOWN! No SNMP response from $IP.";
		my $code = 3;
		exitScript ($output, $code);
	}

	my $extendedOID = $OID . $interfaceOID;
	$command = "/usr/bin/snmpget -v $version -c $community $IP $extendedOID";
	$result = `$command`;
	$result =~ m/^SNMPv2-SMI::enterprises\.9\.9\.147\.1\.2\.1\.1\.1\.3\.4\s=\sINTEGER:\s(\d+)$/;
	my $interfaceStatus = $1;

	$extendedOID = $OID . $primaryOID;
	$command = "/usr/bin/snmpget -v $version -c $community $IP $extendedOID";
	$result = `$command`;
	$result =~ m/^SNMPv2-SMI::enterprises\.9\.9\.147\.1\.2\.1\.1\.1\.3\.6\s=\sINTEGER:\s(\d+)$/;
	my $primaryStatus = $1;

	$extendedOID = $OID . $secondaryOID;
	$command = "/usr/bin/snmpget -v $version -c $community $IP $extendedOID";
	$result = `$command`;
	$result =~ m/^SNMPv2-SMI::enterprises\.9\.9\.147\.1\.2\.1\.1\.1\.3\.7\s=\sINTEGER:\s(\d+)$/;
	my $secondaryStatus = $1;
	
	if ($interfaceStatus != 2)
	{
		my $output = "CRITICAL! Failover interface is down.";
		my $code = 2;
		exitScript ($output, $code);
	}

	if ($primaryStatus != 9)
	{
		my $output = "CRITICAL! Primary unit lost its active role.";
		my $code = 1;
		exitScript ($output, $code);
	}

	if ($secondaryStatus != 10)
	{
		my $output = "CRITICAL! Secondary unit lost its standby role.";
		my $code = 1;
		exitScript ($output, $code);
	}

	my $output = "OK! Failover operation of $IP is fine.";
	my $code = 0;
	exitScript ($output, $code);
}

sub exitScript ()	# Exits the script with an appropriate message and code
{
	print "$_[0]\n";
	exit $_[1];
}

sub getParameters ()	# Obtains script parameters and prints help if needed
{
	my $help = '';

GetOptions ('help|?' => \$help,
		    'C=s' => \$community,
		    'H=s' => \$HOST)

	or pod2usage (1);
	pod2usage (1) if $help;
	pod2usage (1) if (($community eq '') || ($HOST eq ''));
#	pod2usage (1) if ($IP !~ m/^\d+\.\d+\.\d+\.\d+$/);

=head1 SYNOPSIS

check_asa_failover.pl -H <IPaddress> -C <community> | (-help || -?)

=head2 DESCRIPTION

check_asa_failover.pl - this is a Nagios Plugin destined to check the status of Cisco ASA failover peers.


=head1 OPTIONS

Mandatory:

-H	IP address of monitored Cisco ASA device

-C	SNMP community


=cut
}

