#!/usr/local/bin/perl

use strict;
sub Parse_aggr_status_dash_r;
sub commify;

my @aggr_status = ();
my $parity = 0;
my $data = 0;
my $spare = 0;

my $dirname = $0;
$dirname =~ s!/?[^/]*/*$!!;


my $hostname = shift @ARGV or die "Need hostname\n";
my $user = "root";

-r "$dirname/key" or die "Need key file\n";
@aggr_status=`ssh -o UserKnownHostsFile=/dev/null -o CheckHostIP=no -o StrictHostKeyChecking=no -o BatchMode=yes -i $dirname/key $user\@$hostname aggr status -r 2>/dev/null`;
if ( ($? >> 8) > 0 ) {
   die "ssh failed to $hostname\n";
}

while ( $_ = shift @aggr_status ) {
   if ( /^\s*$/ ) {
      next;
   } elsif ( /^\s*RAID group ([\w\/]+)\s+\(([^\)]+)\)$/ ) {
#    RAID group /corpusdb/plex0/rg5 (normal)
      next;
   } elsif ( /^\s*RAID Disk\s+Device\s+HA\s+SHELF\s+BAY\s+CHAN\s+Pool\s+Type\s+RPM\s+Used \(MB\/blks\)\s+Phys \(MB\/blks\)$/ ) {
#      RAID Disk Device  HA  SHELF BAY CHAN Pool Type  RPM  Used (MB/blks)    Phys (MB/blks)
      next;
   } elsif ( /^\s+---------\s+------\s+-------------\s+----\s+----\s+----\s+-----\s+--------------\s+--------------$/ ) {
#      --------- ------  ------------- ---- ---- ---- ----- --------------    --------------
      next;
   } elsif ( /^\s*(dparity|data|parity|spare|partner|failed)\s+(\w+\.\d+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(FC:[A|B])\s+-\s+(FCAL|ATA)\s+(10000|15000|7200)\s+(\d+)\/(\d+)\s+(\d+)\/(\d+)\s+(\(not\s+zeroed\)|\(zeroing, \d+% done\))??\s+$/ ) {
#   } elsif ( /^\s*(dparity|data|parity|spare|partner)\s+(\w+\.\d+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(FC:[A|B])\s+-\s+(FCAL|ATA)\s+(15000|7200)\s+(\d+)\/(\d+)\s+(\d+)\/(\d+)\s+$/ ) {
#      dparity   0g.65   0g    4   1   FC:A   -  FCAL 15000 136000/278528000  137104/280790184
#      parity    0g.43   0g    2   11  FC:A   -  FCAL 15000 136000/278528000  137104/280790184
#      data      0g.50   0g    3   2   FC:A   -  FCAL 15000 136000/278528000  137104/280790184
#spare           6a.107  6a    6   11  FC:A   -  FCAL 15000 68000/139264000   68552/140395088
#partner         6c.49   6c    3   1   FC:B   -  FCAL 15000 68000/139264000   68552/140395088
#partner         0e.29   0e    1   13  FC:B   -  ATA   7200 423111/866531584  423889/868126304
      my $type = $1; my $name=$2; my $size=$9; 
      if ( $type =~/^(dparity|parity)$/ ) { $parity += $size; }
      if ( $type =~/^spare$/ ) { $spare += $size; }
      if ( $type =~/^data$/ ) { $data += $size; }
      next;
   } elsif ( /^Aggregate\s+(\w+)\s+\(([^\)]+)\)\s+\(([^\)]+)\)$/) {
#Aggregate storage1 (online, raid_dp) (block checksums)
      next;
   } elsif (/^\s+Plex ([\w\/]+)\s+\(([^\)]+)\)$/ ) {
#  Plex /storage1/plex0 (online, normal, active)
      next;
   } elsif (/^Broken disks$/ ) {
#Broken disks
      next;
   } elsif (/^Spare disks$/ ) {
#Spare disks
      next;
   } elsif (/^Partner disks$/ ) {
#Partner disks
      next;
   } elsif (/^---------\s+------\s+-------------\s+----\s+----\s+----\s+-----\s+--------------\s+--------------$/ ) {
#---------       ------  ------------- ---- ---- ---- ----- --------------    --------------
      next;
   } elsif (/^Spare disks for block or zoned checksum traditional volumes or aggregates$/ ) { 
#Spare disks for block or zoned checksum traditional volumes or aggregates
      next;
   }
   print;
}

my $total = $parity + $spare + $data;
print "parity:$parity spare:$spare data:$data\n";

sub commify {
	# commify a number. Perl Cookbook, 2.17, p. 64
	my $text = reverse $_[0];
	$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	return scalar reverse $text;
}
