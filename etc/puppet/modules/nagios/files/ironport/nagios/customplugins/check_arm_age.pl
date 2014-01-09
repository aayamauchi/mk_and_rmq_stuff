#!/usr/local/bin/perl --

use strict;
use DBI;
use Getopt::Long;
use vars qw($opt_db $opt_type $opt_user $opt_pass);

my $prog = $0;
$prog =~ s@.*/@@;

GetOptions("db=s", "type=s", "user=s", 'pass=s');

$opt_db ||= "arm-db1.soma.ironport.com";

$opt_type ||= "spam";

my $dbh = DBI->connect("dbi:mysql:arm:$opt_db", "$opt_user" , "$opt_pass");
if (!$dbh) {
    die("$prog: failed to connect to $opt_db\n");
}

my $time = 0;
my $critical = 0;
my $query = "SELECT add_timestamp FROM fpr_${opt_type}_messages f ORDER BY add_timestamp desc LIMIT 1";
my $sth = $dbh->prepare($query);
$sth->execute();
($time) = $sth->fetchrow_array();
$sth->finish();
$dbh->disconnect();

if (!$time) {
    die("$prog: unable to determine latest timestamp\n");
}

if ( $opt_type =~ "spam" ) {
    $critical=28800;
} elsif ( $opt_type =~ "ham" ) {
    $critical=691200;
}

if ( (time() - $time) > $critical ) {
    print "CRITICAL - FPR $opt_type age = " . (time() - $time) . " seconds\n";
    exit 2;
}

print "OK - FPR $opt_type age = " . (time() - $time) . " seconds\n";
exit 0
