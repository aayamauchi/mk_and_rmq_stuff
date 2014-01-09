#!/usr/local/bin/perl
# $Id: //sysops/main/puppet/test/modules/nagios/files/ironport/nagios/customplugins/ip_check_snmp_disk.pl#1 $
#

$NAGIOS_UNKNOWN = 3;
$NAGIOS_CRITICAL = 2;
$NAGIOS_WARNING = 1;
$NAGIOS_OK = 0;

use Getopt::Long;

chomp ($COMMUNITY = `cat /etc/community.txt`);
$OID = ".1.3.6.1.2.1.25.2.3.1";
$DESCR = 3;
$UNITS = 4;
$SIZE = 5;
$USED = 6;
$SNMPWALK = "/usr/bin/snmpbulkwalk -v 2c";
$SNMPGET = "/usr/bin/snmpget -v 2c";

# open T, "> /tmp/snmp_ps.txt";
# print T @ARGV;
# close T;

GetOptions("hostname=s" => \$hostname, "dir=s" => \$dir,
           "crit=s" => \$crit, "warn=s" => \$warn
          );

unless ($hostname and $dir and $crit and $warn) {
  print "Usage: $0 -h hostname -d dir_name -c crit_range -w warn_range\n";
  exit $NAGIOS_UNKNOWN;
}

$snmpcmd = "$SNMPWALK -c $COMMUNITY -On $hostname $OID.$DESCR 2>&1 |";
# print "$snmpcmd\n";
open SNMP, "$snmpcmd";
@lines = <SNMP>;
if ($lines[0] =~ /^\w+: Unknown/) {
  print $lines[0];
  exit $NAGIOS_UNKNOWN;
} elsif ($lines[0] =~ /^Timeout: No Response/) {
  print $lines[0];
  exit $NAGIOS_UNKNOWN;
}

# print $lines[0];
$inst = -1;
foreach $line (@lines) {
  chomp $line;
  ($oid, $type, $value) = snmp_parse($line);
  if ($value =~ /^$dir$/) {
    ($inst = $oid) =~ s/^.*\.(\d+)$/$1/;
    last;
  }
#    print "$inst: $value: $type, $oid\n";
#    $oid =~ /\.(\d+)$/;
#    push @dirs, $1;
#  }
}


if ($inst == -1) {
  print "UNKNOWN: $dir is not mounted\n";
  exit $NAGIOS_UNKNOWN;
}

($oid, $type, $units) = snmpget("$hostname", $COMMUNITY, 
                                "$OID.$UNITS.$inst");
($oid, $type, $size) = snmpget("$hostname", $COMMUNITY, 
                                "$OID.$SIZE.$inst");
($oid, $type, $used) = snmpget("$hostname", $COMMUNITY, 
                                "$OID.$USED.$inst");
if ($size == 0) {
  print "UNKNOWN: size == 0? (inst $inst, dir $dir: size: $size, units: $units, used: $used)\n";
  exit $NAGIOS_UNKNOWN;
}
$size *= $units;
$used *= $units;
$pct = $used / $size * 100;

$message = sprintf "disk $dir: $used/$size bytes (%5.2f%%)", $pct;
$perfdata = "plugin=check_snmp_disk.pl fs=$dir used=$used total=$size";

# normalize crit, warn
if ($crit =~ /%/) {
  $crit =~ s/%//g;
  $warn =~ s/%//g;
  $value = $pct;
} else {
  $value = $used;
}

# is it critical high / low?
if ($crit) {
  ($ret, $text) = range_cmp($crit, $value);
  if (! defined $ret) {
    print "Invalid critical range: $crit\n";
    exit $NAGIOS_UNKNOWN;
  } elsif ($ret == 1) {
    print "Critical: $message: $text|$perfdata\n";
    exit $NAGIOS_CRITICAL;
  }
}

# is it warning high / low?
if ($warn) {
  ($ret, $text) = range_cmp($warn, $value);
  if (! defined $ret) {
    print "Invalid warning range: $warn\n";
    exit $NAGIOS_UNKNOWN;
  } elsif ($ret == 1) {
    print "Warning: $message: $text|$perfdata\n";
    exit $NAGIOS_WARNING;
  }
}

printf "OK: $message|$perfdata\n";
exit $NAGIOS_OK;



##################################

sub snmp_parse {
  my ($input) = (@_);
 
  my $oid, $type, $value;
  $input =~ /^(\S+) = (\S+) (.*)$/;
  $oid = $1;
  $type = $2;
  $value = $3;

  if ($type =~ /STRING/) {
    $value =~ s/^\"(.*)\"$/$1/;
  }
  return ($oid, $type, $value);
}


sub snmpget {
  my ($host, $community, $oid) = (@_);

  $line = `$SNMPGET -c $community -On $host $oid`;
  chomp $line;
  return (snmp_parse($line));
}


# takes two arguments: $range, $value
#
# $value should really be numeric
#
# $range can be lo:hi, lo:, :hi, or hi
#    (inclusive)
#
# returns a flag (0, 1, undef) and a description
#   0 (false) if value falls outside the range
#   1 (true) if value falls inside the range
#   undef if the range is indeterminate
#
sub range_cmp {
  my ($range, $value) = (@_);

  if ($range =~ /^\d+$/ or $range =~ s/^(\d+):$/$1/) {
    # no range: high-water mark
    if ($value >= $range) {
      return (1, "$value >= $range");
    }
  } elsif ($range =~ s/^:(\d+)/$1/) {
    if ($value <= $range) {
      return (1, "$value <= $range");
    }
  } elsif ($range =~ /^(\d+):(\d+)$/) {
    $low = $1; $high = $2;
    if ($value >= $low and $value <= $high) {
      return (1, "$low <= $value <= $high");
    }
  } else {
    return (undef, "Invalid range $range");
  }

  return (0, "$value is outside $range");
} # range_cmp

