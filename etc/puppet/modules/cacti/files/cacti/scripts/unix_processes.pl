#!/usr/local/bin/perl

open(PROCESS, "/bin/ps ax | /bin/grep -c : |");
$output = <PROCESS>;
close(PROCESS);
chomp($output);
print $output;
