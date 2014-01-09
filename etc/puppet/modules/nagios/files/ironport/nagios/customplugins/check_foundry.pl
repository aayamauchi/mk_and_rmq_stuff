#!/usr/local/bin/perl
# vim:ts=4
#
# Check a foundry switch for state of a virtual server
# Steve S 2006
#
# Usage -
# check_foundry [-B] -H switchname [-C community] -v vServerName [-p vPort]
#
# Version 0.1
# Modified by Mike Lindsey [miklinds@ironport.com] to add ability to alert
# on number of active real servers in a pool. - 2008/02/25


use strict;
use Net::SNMP;
use Getopt::Std;

my($CRITACTIVE) = 500;
my($WARNACTIVE) = 400;
my($CRITREAL) = -1;
my($WARNREAL) = -1;
my($FOUNDRY) = '1.3.6.1.4.1.1991';
my($TIMEOUT) = 4;
my($DEBUG) = 0;
my($COMMUNITY) = 'public';
my($SWITCH) = '';
my($VSERVER) = '';
my($VPORT) = '';

my(%vports) = ();
my(%rports) = ();
my(%bind) = ();
my(%global) = ();

my($MSG,$STATUS) = ("",3);

use vars qw/$opt_c $opt_w $opt_h $opt_d $opt_H $opt_s $opt_v $opt_B $opt_p $opt_M $opt_T $opt_C $opt_W/;
my($snmp,$snmperr,$resp);
my($maxr,$okr,$state);

###########################################################################
sub dohelp() 
{
	print "To perform Nagios checks:\n";
	print "check_foundry -H switchname [-s community] -v vServerName [-p vPort]\n";
	print "To list vServers (info only)\n";
	print "check_foundry -H switchname [-s community]\n";
	print "To list rServer bindings (info only)\n";
	print "check_foundry -B -H switchname [-s community] [-v vServerName [-p vPort]]\n";
	print "For MRTG output (total active sessions)\n";
	print "check_foundry -M -H switchname [-s community]\n";
	print "For MRTG output (active sessions, rServer count)\n";
	print "check_foundry -M -H switchname [-s community] -v vServerName [-p vPort]\n";
	print "Add -d for debug mode.\n";
	print "Use -w and -c to set thresholds for number of Active sessions ($WARNACTIVE, $CRITACTIVE)\n";
	print "Use -W and -C to set thresholds for number of active real servers ($WARNREAL, $CRITREAL)\n";

	exit 0;
}
sub dooutput() {
	if($opt_M) {
		print "U\nU\n\nError: $MSG ($STATUS)\n"; exit 0;
	}
	$MSG = "Status: $STATUS" if(!$MSG);
	$STATUS = 3 if($STATUS<0 or $STATUS>3);
	print "$MSG\n";
	exit $STATUS;
}
###########################################################################
sub readfoundry()
{
	my($k,$oid,$seq);

	print "Starting SNMP\n" if($DEBUG);
	($snmp,$snmperr) = Net::SNMP->session( -hostname=>$SWITCH,
		-community=>$COMMUNITY, -timeout=>$TIMEOUT, -retries=>2 );
	if($snmperr) {
		print "($snmperr)\n" if($DEBUG);
		$MSG = "Error: $snmperr";
		$STATUS = 3;
		dooutput; # exit
		exit(0);
	}

	# gather general stats
	$resp = $snmp->get_request( -varbindlist=>[
		"$FOUNDRY.1.1.4.1.1.0",
		"$FOUNDRY.1.1.4.1.13.0"
	] );
	if(!$resp) {
		$MSG = "Error: Cannot read general OIDs";
		$STATUS = 3;
		dooutput; # exit
	}
	$global{active} = $resp->{"$FOUNDRY.1.1.4.1.1.0"}
		-$resp->{"$FOUNDRY.1.1.4.1.13.0"};

	# Optimise
	if(!$VSERVER and $opt_M) { $snmp->close; return; }

	# Gather vport  stats
	print "Getting vport table\n" if($DEBUG);
	$resp = $snmp->get_table( -baseoid=>"$FOUNDRY.1.1.4.26");
	if(!$resp) {
		$MSG = "Error: Cannot read VPort Statistics table";
		$STATUS = 3;
		dooutput; # exit
	}
	foreach $oid ( keys %{$resp} ) {
		$oid =~ /\.(\d+)\.(\d+\.\d+\.\d+\.\d+\.\d+)$/;
#		print "$oid\n" if($DEBUG);
		if($1 == 3) {
			$seq = $2;
			$k = $resp->{$oid}.":".$resp->{"$FOUNDRY.1.1.4.26.1.1.2.$seq"};
#			print "Adding vport:$k\n" if($DEBUG);
			$vports{$k} = {
				seq=>$seq,
				vserver=>$resp->{$oid},
				vport=>$resp->{"$FOUNDRY.1.1.4.26.1.1.2.$seq"},
				vip=>$resp->{"$FOUNDRY.1.1.4.26.1.1.1.$seq"},
				active=>$resp->{"$FOUNDRY.1.1.4.26.1.1.4.$seq"},
				total=>$resp->{"$FOUNDRY.1.1.4.26.1.1.5.$seq"}
			};
			$VPORT = $resp->{"$FOUNDRY.1.1.4.26.1.1.2.$seq"}
				if($resp->{$oid} eq $VSERVER and !$VPORT);
		}
	}
 
	# Gather Rport stats
	print "Getting rport table\n" if($DEBUG);
	$resp = $snmp->get_table( -baseoid=>"$FOUNDRY.1.1.4.24");
	if(!$resp) {
		$MSG = "Error: Cannot read RPort Statistics table";
		$STATUS = 3;
		dooutput; # exit
	}
	foreach $oid ( keys %{$resp} ) {
		$oid =~ /\.(\d+)\.(\d+\.\d+\.\d+\.\d+\.\d+)$/;
		if($1 == 3) {
			$seq = $2;
			$k = $resp->{$oid}.":".$resp->{"$FOUNDRY.1.1.4.24.1.1.2.$seq"};
			$rports{$k} = {
				seq=>$seq,
				vserver=>$resp->{$oid},
				vport=>$resp->{"$FOUNDRY.1.1.4.24.1.1.2.$seq"},
				vip=>$resp->{"$FOUNDRY.1.1.4.24.1.1.1.$seq"},
				active=>$resp->{"$FOUNDRY.1.1.4.24.1.1.7.$seq"},
				total=>$resp->{"$FOUNDRY.1.1.4.24.1.1.8.$seq"},
				state=>$resp->{"$FOUNDRY.1.1.4.24.1.1.5.$seq"}
			};
		}
	}

	# Gather bind information
	print "Getting bind table\n" if($DEBUG);
	$resp = $snmp->get_table( -baseoid=>"$FOUNDRY.1.1.4.6");
	if(!$resp) {
		$MSG = "Error: Cannot read bind table";
		$STATUS = 3;
		dooutput; # exit
	}
	foreach $oid ( keys %{$resp} ) {
		$oid =~ /\.(\d+)\.(\d+)$/;
#		print "$oid\n" if($DEBUG);
		if($1 == 2) {
			$seq = $2;
			$k = $resp->{$oid}.":".$resp->{"$FOUNDRY.1.1.4.6.1.1.3.$seq"};
			$bind{$k} = () if(!defined $bind{$k});
			push @{$bind{$k}}, 
				($resp->{"$FOUNDRY.1.1.4.6.1.1.4.$seq"}.":"
				.$resp->{"$FOUNDRY.1.1.4.6.1.1.5.$seq"});

		}
	}

	$snmp->close();
}
sub listvservers()
{
	print "Listing all vservers...\n" if($DEBUG);
	print "VServer Name    IP Address      Port  Svrs Active\n";
	foreach ( keys %vports ) {
		printf "%-15s %-16s %5d %3d (%5d)\n",
			$vports{$_}{vserver},$vports{$_}{vip},$vports{$_}{vport},
			($#{$bind{$_}}+1), $vports{$_}{active};
	}
}
sub listbindings()
{
	if(!$VSERVER) {
		foreach ( keys %bind ) {
			print $_.": ".(join ',',@{$bind{$_}})."\n";
		}
	} else {
		print "Bindings for $VSERVER:$VPORT :\n";
		print "".(join ', ',@{$bind{"$VSERVER:$VPORT"}})."\n";
	}
}

###########################################################################

getopts('dhH:C:W:s:w:c:v:p:MT:B');
dohelp if($opt_h);
$DEBUG = 1 if($opt_d);
$COMMUNITY = $opt_s if($opt_s);
$SWITCH = $opt_H if($opt_H);
$VSERVER = $opt_v if($opt_v);
$VPORT = $opt_p if($opt_p);
$TIMEOUT = $opt_T if($opt_T);
$WARNREAL = $opt_W if ($opt_W);
$CRITREAL = $opt_C if ($opt_C);
$WARNACTIVE = $opt_w if ($opt_w);
$CRITACTIVE = $opt_c if ($opt_c);

if(!$SWITCH) {
	$STATUS = 3; $MSG = "Must specify foundry switch name.";
	dooutput; exit 3;
}
if(!$COMMUNITY) {
	$STATUS = 3; $MSG = "Must specify SNMP community string.";
	dooutput; exit 3;
}
readfoundry;

if(!$VSERVER) {
	if($opt_M) {
		print $global{active}."\n"
			.$global{active}."\n\n"
			.$global{active}." active sessions.\n";
		exit 0;
	} elsif($opt_B) {
		listbindings;
	} else {
		listvservers;
	}
	exit(0);
}

if( $VSERVER =~ /(\S+):(\d+)/ ) { ($VSERVER,$VPORT) = ($1,$2); }
if( $VSERVER =~ /\d+\.\d+\.\d+\.\d+/ ) {
	foreach ( keys %vports ) {
		if( $vports{$_}{vip} eq $VSERVER ) {
			$VSERVER = $vports{$_}{vserver};
			$VPORT = $vports{$_}{vport} if(!$VPORT);
			last;
		}
	}
}

# Now, identify the vserver...
if(!defined $vports{"$VSERVER:$VPORT"}) {
	$MSG = "That Server/port is not recognised ($VSERVER:$VPORT)";
	$STATUS = 3;
	dooutput; exit 3;
}

# Bindings
listbindings if($DEBUG or $opt_B);
exit 0 if($opt_B);

if($opt_M) {
	print $vports{"$VSERVER:$VPORT"}{active}."\n";
	print "".(1+$#{$bind{"$VSERVER:$VPORT"}})."\n";
	print "\n";
	print "Active: ".$vports{"$VSERVER:$VPORT"}{active}
		." RServers: ".(1+$#{$bind{"$VSERVER:$VPORT"}})."\n";
	exit 0;
}

# Now, we need to work out which RServers we have and their health.
$STATUS = 0;

$MSG = $vports{"$VSERVER:$VPORT"}{active} . " active sessions to $VSERVER:$VPORT";

$maxr = $#{$bind{"$VSERVER:$VPORT"}} + 1;
$okr  = 0;
foreach ( @{$bind{"$VSERVER:$VPORT"}} ) {
	# loop through the rservers
	$state = $rports{$_}{state};
    if($DEBUG) {
        print "$_ $state\n";
    }
	if($state == 6) { $okr +=1; next; } # active
	if($state == 1) {
		$MSG .= ", RServer $_ is only ENABLED"; # $STATUS= 2;
	} elsif($state == 2) {
		$MSG .= ", RServer $_ is FAILED"; #$STATUS= 2;
	} elsif($state == 3) {
		$MSG .= ", RServer $_ is TESTING"; #$STATUS= 1 if($STATUS<2);
	} elsif($state == 4) {
		$MSG .= ", RServer $_ is SUSPECT"; #$STATUS= 1 if($STATUS<2);
	}
}
if($maxr == $okr ) {
	$MSG .= ". All $maxr RealServers are active.";
} else {
	$MSG .= ". $okr/$maxr RealServers are active.";
}

if( $vports{"$VSERVER:$VPORT"}{active} > $CRITACTIVE ) {
	$STATUS = 2; 
} elsif( $vports{"$VSERVER:$VPORT"}{active} > $WARNACTIVE ) {
	$STATUS = 1; 
}
if ($okr < $CRITREAL && $CRITREAL > -1) {
    $STATUS = 2;
} elsif ($okr < $WARNREAL && $okr >= $CRITREAL && $WARNREAL > -1) { 
    $STATUS = 1 if ($STATUS <2);
}

if ($STATUS == 0) {
    $MSG = "OK: " . $MSG;
} elsif ($STATUS == 1) {
    $MSG = "WARN: " . $MSG;
} elsif ($STATUS == 2) {
    $MSG = "CRIT: " . $MSG;
}

dooutput;
exit(3);
