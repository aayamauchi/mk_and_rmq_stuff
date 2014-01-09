#!/usr/local/bin/perl

# take care for tcp:hostname or TCP:ip@
$host = $ARGV[0];
$host =~ s/tcp:/$1/gis;

open(PROCESS, "/bin/ping -n -c 1 $host | grep icmp_seq | grep time |");
$ping = <PROCESS>;
close(PROCESS);
$ping =~ m/(.*time=)(.*) (ms|usec)/;

if ($2 == "") {
	print "U"; 		# avoid cacti errors, but do not fake rrdtool stats
}elsif ($3 eq "usec") {
	print int($2/1000);	# re-calculate in units of "ms"
}else{
	print int($2);
}
