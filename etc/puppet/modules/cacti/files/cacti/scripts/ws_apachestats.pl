#!/usr/local/bin/perl -w

# Copyright - Rolf Poser - rolf@stasolutions.co.za
# 19 May 2004 under the GPL license agreement!
#
# HIGH-SPEED VERSION - requires lynx or wget !!
# If you don't have either, please use the default version.
#
# Version 0.4 - PLEASE SEE README.txt and TUNING.txt for more information.
#
# USAGE:
#
# perl unix_apachestats.pl <hostname>
#
# <hostname> is optional and can be an IP address or host name.
#            If none is given, "localhost" is assumed.
#            The cacti configuration should normally take care of this..
#
# LOCAL SETTINGS:
#
# I've found wget to be the most efficient, but if you're not so fussy
# about speed, and/or would rather stick to lynx, you may change the default
# below:
#

$RETRIEVER="/usr/bin/wget --no-check-certificate --user-agent=\"ApacheStats\/0.4 wget\/1.8\" -q -O - -t3 -T5";
#$RETRIEVER="/usr/bin/lynx -useragent=\"ApacheStats\/0.4 Lynx\/2.8\" -dump";

# Change the following if you have an environment variable of "http_proxy"
# that interferes with your direct access to the web server in question.
# The symptoms are that the ACL on the server disallows you access because
# you are connecting via a proxy server:

delete $ENV{'HTTP_PROXY'};
delete $ENV{'http_proxy'};

#
# YOU SHOULDN"T NEED TO CHANGE ANYTHING BEYOND THIS POINT..
#

# First get hold of any supplied hostname, otherwise set to "localhost"

my $hostname = $ARGV[0];


if (!$hostname) {
        $hostname = "localhost";
}
chomp $hostname;

# Set the query URL:

$URL = "http:\/\/".$hostname.":8080\/server-status?auto";
$URL2 = "http:\/\/".$hostname."\/server-status?auto";

# Run the query:

$output = `$RETRIEVER $URL`;

if ( ("$output" =~ m/^\{/ ) || ("$output" eq "") ) {
	$output = `$RETRIEVER $URL2`;
}


# Parse the output and put out the stats to STDOUT:

my $out = "";
$output =~ /Total Accesses: (.*)/; 
$out .= "apache_total_hits:".$1." " if defined($1);
$output =~ /Total kBytes: (.*)/; 
$out .= "apache_total_kbytes:".$1." " if defined($1);
$output =~ /Busy.*: (.*)/;
$out .= "apache_busy_workers:".$1." " if defined($1);
$output =~ /Idle.*: (.*)/;
$out .= "apache_idle_workers:".$1." " if defined($1);

# added Scoreboard for thread status
$output =~ /Scoreboard: (.*)/;
if ( defined($1) and $1 ne "" ) {
	my $string = $1;

	my %threads = (
			"_" => 0,	# waiting
			"S" => 0,	# starting up
			"R" => 0,	# reading request
			"W" => 0,	# sending reply
			"K" => 0,	# keepalive
			"D" => 0,	# DNS lookup
			"C" => 0,	# closing connection
			"L" => 0,	# logging
			"G" => 0,	# graceful finishing
			"I" => 0,	# idle cleanup
			"." => 0	# open slot
		   );
	
	foreach my $type (split //, $string) {
	    $threads{$type}++;
	}
	
	foreach $type (sort keys %threads) {
		SWITCH: {
	    		if ( $type eq "." ) { $out .= "thread_O:$threads{$type} "; last SWITCH; }
	    		if ( $type eq "_" ) { $out .= "thread_W:$threads{$type} "; last SWITCH; }
	    		$out .= "thread".$type.":$threads{$type} ";
		}
	}
}

# added CPULoad
$output =~ /CPULoad.*: (.*)/;
$out .= "apache_cpuload:".$1 if defined($1);

# print using only one single statement (cactid requires this)
print $out;

# FIN
