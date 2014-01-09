#!/usr/local/bin/perl

# Copyright 2007 GroundWork Open Source Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 2
# of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Author Dr. Dave Blunt at GroundWork Open Source Inc.
#       (dblunt@groundworkopensource.com)

# Revision history:
#
#  2007/03/21 - Initial revision

my %ERRORS = (
        'UNKNOWN', '-1',
        'OK', '0',
        'WARNING', '1',
        'CRITICAL', '2');

my $state="UNKNOWN";

my $host=$ARGV[0];
my $user=$ARGV[1];
my $mysql_command;
my $variable;
my $pass;
my $val1,$val2;
my $warn,$crit;

if (@ARGV == 0 || @ARGV < 5) {
  print "Usage:  check_mysql_innodb.pl\n\n";
  print "  <hostname/IP>  <user>  [<password>]  \"<variable>\"   <warn>  <crit>\n\n";
  print "    <variable> =	Pending normal AIO reads\n";
  print "			Buffer pool hit rate\n";
  print "			Row inserts per second\n";
  print "			Row updates per second\n";
  print "			Row deletes per second\n";
  print "			Row reads per second\n";
  print "			Fsyncs per second\n";
  print "			Average bytes per read\n";
  print "			File reads per second\n";
  print "			File writes per second\n";
  print "			Buffer reads per second\n";
  print "\n";
  print "    (If <warn> is higher than <crit> as is desired in Buffer pool\n";
  print "     hit rate check, then it will be as a reverse threshold.)\n";
  print "\n";
  print "  Example usage:\n\n";
  print "    check_mysql_innodb.pl localhost root \"Row reads per second\" 5 10\n\n";
  print "    OK:  Row reads per second = 1.75\n\n";
  exit $ERRORS{"UNKNOWN"};
}

if ($ARGV[2] && (@ARGV == 4 || @ARGV == 6)) {
  $pass=$ARGV[2];
  $mysql_command='mysql -h ' . $host . ' -u ' . $user . ' --password="' . $pass . '" -e "show innodb status"';
  $variable=$ARGV[3];
} else {
  $mysql_command='mysql -h ' . $host . ' -u ' . $user . ' -e "show innodb status"';
  $variable=$ARGV[2];
}

if (@ARGV == 5 ) {
  $warn=$ARGV[3];
  $crit=$ARGV[4];
} elsif (@ARGV == 6 ) {
  $warn=$ARGV[4];
  $crit=$ARGV[5];
}

my @line=`$mysql_command`;
if (!@line) {
  print "UNKNOWN:  Unable to retrieve data from MySQL server.";
  $state="UNKNOWN";
  exit $ERRORS{"$state"};
}
my $result=join('\\n',@line);

@lines=split(/\\n-+\\n.*?\\n-+\\n/, $result);

# format of show innodb status should result in the following lines:
#
# SEMAPHORES					 - line 1
# TRANSACTIONS					 - line 2
# FILE I/O					 - line 3
# INSERT BUFFER AND ADAPTIVE HASH INDEX		 - line 4
# LOG						 - line 5
# BUFFER POOL AND MEMORY			 - line 6
# ROW OPERATIONS				 - line 7

if ($variable =~ /Pending normal AIO reads/) {
  ($value)=$lines[3]=~/Pending normal aio reads: ([\d\.]+),/;
} elsif ($variable =~ /Buffer pool hit rate/) {
  ($val1,$val2)=$lines[6]=~/Buffer pool hit rate ([\d\.]+) \/ ([\d\.]+)/;
  $value=$val1*100/$val2;
} elsif ($variable =~ /Row inserts per second/) {
  ($value)=$lines[7]=~/([\d\.]+) inserts\/s/;
} elsif ($variable =~ /Row updates per second/) {
  ($value)=$lines[7]=~/([\d\.]+) updates\/s/;
} elsif ($variable =~ /Row deletes per second/) {
  ($value)=$lines[7]=~/([\d\.]+) deletes\/s/;
} elsif ($variable =~ /Row reads per second/) {
  ($value)=$lines[7]=~/([\d\.]+) reads\/s/;
} elsif ($variable =~ /Fsyncs per second/) {
  ($value)=$lines[3]=~/([\d\.]+) fsyncs\/s/;
} elsif ($variable =~ /Average bytes per read/) {
  ($value)=$lines[3]=~/([\d\.]+) avg bytes\/read/;
} elsif ($variable =~ /File reads per second/) {
  ($value)=$lines[3]=~/([\d\.]+) reads\/s/;
} elsif ($variable =~ /File writes per second/) {
  ($value)=$lines[3]=~/([\d\.]+) writes\/s/;
} elsif ($variable =~ /Buffer reads per second/) {
  ($value)=$lines[6]=~/([\d\.]+) reads\/s/;
} else {
  print "UNKNOWN:  Specified variable unknown.";
  exit $ERRORS{"UNKNOWN"};
}
  if ($warn && $crit) {
    if ($warn < $crit) {
      if ($value >= $crit) {
        $state="CRITICAL";
      } elsif ($value >= $warn) {
        $state="WARNING";
      } else {
        $state="OK";
      }
    } else {
      if ($value <= $crit) {
        $state="CRITICAL";
      } elsif ($value <= $warn) {
        $state="WARNING";
      } else {
        $state="OK";
      }
    }
  }

  print "$state: $variable = $value|value=$value\;$warn\;$crit\;\;\n";
  exit $ERRORS{"$state"};
