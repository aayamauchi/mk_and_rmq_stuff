#!/usr/local/bin/perl

my $grep_string = $ARGV[0];

chomp $grep_string;

if ($grep_string eq '') {
	open(PROCESS, "/usr/bin/who | /bin/grep -c : |");
}else{
	open(PROCESS, "/usr/bin/who | /bin/grep : | /bin/grep -c $grep_string |");
}
$output = <PROCESS>;
close(PROCESS);
chomp($output);
print $output;
