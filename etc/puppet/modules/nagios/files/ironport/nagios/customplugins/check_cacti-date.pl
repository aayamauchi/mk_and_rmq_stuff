#!/usr/local/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Time::Local;

$| = 1;

my $Mdbh;
my %options;
my $vf;
my $exit;

sub usage() {
	print "start - usage()\n" if $vf;
	print STDERR qq(
usage: $0 [-h]|[-n hostname -u user -p password] -w warning -c critical [-v]

	-h this message
	-n hostname to connect to
	-u username to connect as
	-p password to use
	-w warning threshold in seconds
	-c critical threshold in seconds
	-v verbose output

example: $0 -n localhost -u cactiuser -p cactipassword -w 600 -c 960

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
			"c:s"=>\$options{'critical'},
			"w:s"=>\$options{'warning'});
	print "init() - verbose on\n" if $vf;
	usage() if $hf;

	my $missingflags = 0;

	if (!$options{'database'}) {	$options{'database'}	= "cacti"; }
	if (!$options{'user'}) { 	$options{'user'}	= "cactiuser"; }
	if (!$options{'password'}) {	$options{'password'}	= "cactipassword"; }

	if (!$options{'critical'}) { $missingflags++; }
	if (!$options{'warning'}) { $missingflags++; }

	if ($missingflags) {
		usage();
	}

	print "end   - init()\n" if $vf;
}

sub initdb() {
	print "start - initdb()\n" if $vf;

	opendb();
	my $query;
	my $sth;
	my @array;

	# | 2006-11-03 21:51:54 |

	$query = "select value from settings where name='date'";
	$sth = $Mdbh->prepare($query);
	$sth->execute() or die $@;

	my $date = $sth->fetchrow_array();

	my ($day, $time) = split(/ /, $date);
	my ($yr, $mo, $dy) = split(/-/, $day);
	my ($hr, $mn, $sc) = split(/:/, $time);
	my $lastrun = timelocal($sc, $mn, $hr, $dy, ($mo-1), ($yr-1900));

	$lastrun = time() - $lastrun;

	if ($lastrun > $options{'critical'}) { 
		print "CRITICAL: ";
		$exit = 2;
	} elsif ($lastrun > $options{'warning'}) {
		print "WARNING: ";
		$exit = 1;
	} else {
		print "OK: ";
		$exit = 0;
	}

	print "last cacti run $lastrun seconds ago.\n";

	print "end   - initdb()\n" if $vf;
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
initdb();
closedb();
exit($exit);
