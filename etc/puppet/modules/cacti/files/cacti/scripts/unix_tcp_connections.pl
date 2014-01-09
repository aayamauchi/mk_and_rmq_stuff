#!/usr/local/bin/perl

my $grep_string = $ARGV[0];

chomp $grep_string;

if ($grep_string eq '') {
	open(PROCESS, "/bin/netstat -n | /bin/grep -c tcp | ");
}else{
	open(PROCESS, "/bin/netstat -n | /bin/grep tcp | /bin/grep -c $grep_string |");
}
$output = <PROCESS>;
close(PROCESS);
chomp($output);
print $output;
