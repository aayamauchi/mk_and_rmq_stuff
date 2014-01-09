#!/usr/local/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Time::Local;

$| = 1;

my $Mdbh;
my %options;
my $vf;
my $exit = 0;

sub usage() {
	print "start - usage()\n" if $vf;
	print STDERR qq(
usage: $0 [-h]|[-n hostname -u user -p password] [-w warning -c critical] -s stat [-v]

	-h this message
	-n hostname to connect to
	-u username to connect as
	-p password to use
	-w warning threshold for nagios if >value.  :num for <value
	-c critical threshold for nagios
	-s stat to query
		[time|method|processes|threads|hosts|hostsperprocess|datasources|
		 rrdsprocessed|dsminrrd]
	-v verbose output

example: $0 -s localhost -u cactiuser -p cactipassword -s dsminrrd -w 100 -c 200
		- Will give a warning if more than 100 data sources aren't updated.
		  and a critical if more than 200.
example: $0 -s localhost -u cactiuser -p cactipassword -s time
		- prints out time taken for last poll cycle in seconds.


);
	exit(3);
}

sub init() {
	my $hf;

	my $opt_string	=	"hnupwc";
	GetOptions(	"h!"=>\$hf,
			"v!"=>\$vf,
			"n=s"=>\$options{'hostname'},
			"u=s"=>\$options{'user'},
			"p=s"=>\$options{'password'},
			"s:s"=>\$options{'stat'},
			"c=s"=>\$options{'critical'},
			"w=s"=>\$options{'warning'});
	print "init() - verbose on\n" if $vf;
	usage() if $hf;

	my $missingflags = 0;

	if (!$options{'database'}) {	$options{'database'}	= "cacti"; }
	if (!$options{'hostname'}) {	$options{'hostname'}	= "localhost"; }
	if (!$options{'user'}) { 	$options{'user'}	= "cactiuser"; }
	if (!$options{'password'}) {	$options{'password'}	= "cactipassword"; }

	if (!$options{'stat'}) {	print "Missing stat\n"; $missingflags++; }

	if ($missingflags) {
		usage();
	}

	print "end   - init()\n" if $vf;
}

sub queryandcheck() {
	print "start - queryandcheck()\n" if $vf;

	opendb();
	my $query;
	my $sth;
	my %stathash;
	my $gt = 1;

	# | 2006-11-03 21:51:54 |

	$query = "select value from settings where name='stats_poller'";
	$sth = $Mdbh->prepare($query);
	$sth->execute() or die $@;

	my $stats = lc($sth->fetchrow_array());

	my ($name, $value);

	foreach my $stat (split(/ /,$stats)) {
		($name, $value) = split(/:/,$stat);
		$stathash{$name} = $value;
	}

	$stathash{'dsminrrd'} =	$stathash{'datasources'} - $stathash{'rrdsprocessed'};

	unless ($stathash{$options{'stat'}}) {
		print "UNKNOWN: invalid cacti stat $options{'stat'}\n";
		closedb();
		exit(3);
	}
	
	if ($options{'critical'}) {
		if ($options{'critical'} =~ m/:/) {
			$gt = 0;
			$options{'critical'} =~ s/://;
		}
		if (($options{'critical'} < $stathash{$options{'stat'}} && $gt == 1) || ($options{'critical'} > $stathash{$options{'stat'}} && $gt == 0)) {
			print "CRITICAL: cacti stat $options{'stat'} ";
			$exit = 2;
		}
	}
	if ($options{'warning'} && $exit != 2) {
		if ($options{'warning'} =~ m/:/) {
			$gt = 0;
			$options{'warning'} =~ s/://;
		}
		if (($options{'warning'} < $stathash{$options{'stat'}} && $gt == 1) || ($options{'warning'} > $stathash{$options{'stat'}} && $gt == 0)) {
			print "WARNING: cacti stat $options{'stat'} ";
			$exit = 1;
		}
	}

	print "$stathash{$options{'stat'}}\n";

	print "end   - queryandcheck()\n" if $vf;
}

sub opendb() {
	print "start - opendb()\n" if $vf;

	my $Mdbc;
	$Mdbc = "dbi:mysql:database=$options{'database'};host=$options{'hostname'};port=3306";

	$Mdbh = DBI->connect ( $Mdbc, $options{'user'}, $options{'password'}) or die "DB connection failed: $DBI::errstr\n";

	print "end   - opendb()\n" if $vf;
}

sub closedb() {
	print "start - closedb()\n" if $vf;
	$Mdbh->disconnect;
	print "end   - closedb()\n" if $vf;
}

init();
queryandcheck();
closedb();
exit($exit);
