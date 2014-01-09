#!/usr/local/bin/perl --
#
#
#	gen_fom_xml.pl	v1.0	6/22/2006
#
#	Copyright 2006 GroundWork Open Source Solutions, Inc. ("GroundWork")  
#	All rights reserved. Use is subject to GroundWork commercial license terms.
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#	WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#	License for the specific language governing permissions and limitations under
#	the License.
#
use strict;
use Time::Local;
use lib "/usr/local/monarch/lib";
use MonarchImport;
use MonarchStorProc;

my $debug = 1;
my $fom_name = "FOM-TEMPLATE";
if ($ARGV[0]) {
	$fom_name = $ARGV[0]
}

my $FOM_host = "Figure_Of_Merits";
my $FOM_host_ipaddress = "127.0.0.1";
my $FOM_passive_servicename = "Passive";
my $FOM_calculation_servicename = "Calculation";
my $FOM_calculation_filename = "$fom_name.xml";



#my $xmlfile = "/usr/local/nagios/etc/gen_fom.xml";
my $xmlfile = "$fom_name.xml";
my $csvfile = "$fom_name.csv";

my $default_weight = 1;
#my $default_weight = "TOTAL";
my $default_warning = "66.66";
my $default_critical = "33.33";

my ($nagios_ver, $nagios_bin, $nagios_etc, $monarch_home, $backup_dir, $is_portal, $upload_dir) = ();
my $user_acct = "super_user";		# Monarch user account
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900;
my $month=qw(January February March April May June July August September October November December)[$mon];
my $timestring= sprintf "%02d:%02d:%02d",$hour,$min,$sec;
my $thisday = qw(Sunday Monday Tuesday Wednesday Thusday Friday Saturday)[$wday];

# Connect to Monarch
StorProc->dbconnect() or error("Can't connect to Monarch database\n",1);

#
#	Now get Monarch hostgroup list
#
print "Get Monarch host groups.\n" ;
my $monarch_hg_ref = undef;
my %wherehash = ();
my %hgs = StorProc->fetch_list_hash_array('hostgroups',\%wherehash);
foreach my $hg_id (sort keys %hgs) {
	$monarch_hg_ref->{NAME}->{$hgs{$hg_id}[1]}->{ID} = $hg_id;		# Instantiate each monarch host group name and ID
#	print "\tHost group $hgs{$hg_id}[1].\n";
#	Get Monarch members
	my %wherehash = ('hostgroup_id' => $hg_id);
	my @hg_members_id = StorProc->fetch_list_where('hostgroup_host','host_id',\%wherehash);
	foreach my $member_id (sort @hg_members_id) {
		my %wherehash = ('host_id' => $member_id);
		my %hostitem = StorProc->fetch_one_where('hosts',\%wherehash);					# Get host name using host id
		$monarch_hg_ref->{NAME}->{$hgs{$hg_id}[1]}->{HOSTS}->{$hostitem{name}}->{EXISTS} = 1;
		print "\t\tHost name $hostitem{name}.\n";
		my %services_wherehash = ('host_id' => $member_id);
		my @service_members_id = StorProc->fetch_list_where('services','servicename_id',\%services_wherehash);
		foreach my $service_id (@service_members_id) {
			my %servicenames_wherehash = ('servicename_id' => $service_id);
			my %service_hash = StorProc->fetch_one_where('service_names',\%servicenames_wherehash);
			$monarch_hg_ref->{NAME}->{$hgs{$hg_id}[1]}->{HOSTS}->{$hostitem{name}}->{SERVICES}->{$service_hash{name}}->{EXISTS} = 1;
			$monarch_hg_ref->{NAME}->{$hgs{$hg_id}[1]}->{SERVICES}->{$service_hash{name}}->{HOSTS}->{$hostitem{name}}->{EXISTS} = 1;
			print "\t\t\tService id $service_id, name $service_hash{name}.\n";
		}
	}
}


open XML,">$xmlfile" or die "Can't open output file $xmlfile\n";
open CSV,">$csvfile" or die "Can't open output file $csvfile\n";
print CSV "Host,Host_IPAddress,ServiceName,Name,File\n";
print CSV "$FOM_host,$FOM_host_ipaddress,$FOM_calculation_servicename,$fom_name,$FOM_calculation_filename\n";


print XML "<FOM NAME=\"$fom_name\">\n";
foreach my $hostgroup (sort keys %{$monarch_hg_ref->{NAME}}) {
	$hostgroup =~ s/\s/_/g;
	print XML "<FOM_GROUP NAME=\"$hostgroup\" WEIGHT=\"$default_weight\" WARNING=\"$default_warning\" CRITICAL=\"$default_critical\">\n";
	my $tmp = substr("Group_$hostgroup",0,59);		# Nagios service name limit is 63 characters
	print CSV "$FOM_host,$FOM_host_ipaddress,$FOM_passive_servicename,$tmp\n";
	# Generate hosts hierarchy
	print XML "\t<HOSTS>\n";
	foreach my $host (sort keys %{$monarch_hg_ref->{NAME}->{$hostgroup}->{HOSTS}}) {
		print XML "\t\t<HOST NAME=\"$host\" WEIGHT=\"$default_weight\" WARNING=\"$default_warning\" CRITICAL=\"$default_critical\">\n";
		my $tmp = substr("Host_$host",0,59);		# Nagios service name limit is 63 characters
		print CSV "$FOM_host,$FOM_host_ipaddress,$FOM_passive_servicename,$tmp\n";
		foreach my $service (sort keys %{$monarch_hg_ref->{NAME}->{$hostgroup}->{HOSTS}->{$host}->{SERVICES}}) {
			my $linkstring = undef;
			if ($service =~ /ganglia/i) {
				my $linklabel = "Ganglia page for $host";
				my $link = "http://gto-graphs.cadence.com/?c=Cadence&amp;h=$host";
				$linkstring = "LINKLABEL=\"$linklabel\" LINK=\"$link\"";
				# sample graph link: http://gto-graphs.cadence.com//graph.php?g=load_report&z=medium&c=Cadence&h=cdsrld01&m=&r=hour&s=descending&hc=3&st=1169750310
			} elsif ($service =~ /cacti/i) {
				my $linklabel = "Cacti page";
				my $link = "http://gto-cacti.cadence.com/";
				$linkstring = "LINKLABEL=\"$linklabel\" LINK=\"$link\"";
			} elsif ($service =~ /(wiley|introscope)/i) {
				my $linklabel = "Wiley Introscope page";
				my $link = "http://appmon.cadence.com:8080/";
				$linkstring = "LINKLABEL=\"$linklabel\" LINK=\"$link\"";
			}
			print XML "\t\t\t<METRIC NAME=\"$service\" LABEL=\"$service\" WEIGHT=\"$default_weight\" $linkstring  WARNING=\"$default_warning\" CRITICAL=\"$default_critical\"/>\n";
		}
		print XML "\t\t</HOST>\n";
	}
	print XML "\t</HOSTS>\n";
	# Generate services hierarcy
	print XML "\t<SERVICES>\n";
	foreach my $service (sort keys %{$monarch_hg_ref->{NAME}->{$hostgroup}->{SERVICES}}) {
		print XML "\t\t<SERVICE NAME=\"$service\" LABEL=\"$service\" WEIGHT=\"$default_weight\"  WARNING=\"$default_warning\" CRITICAL=\"$default_critical\">\n";
		foreach my $host (sort keys %{$monarch_hg_ref->{NAME}->{$hostgroup}->{SERVICES}->{$service}->{HOSTS}}) {
			my $tmp = substr("SGroup_$hostgroup\__Svc_$service",0,59);		# Nagios service name limit is 63 characters
			print CSV "$FOM_host,$FOM_host_ipaddress,$FOM_passive_servicename,$tmp\n";
			my $linkstring = undef;
			if ($service =~ /ganglia/i) {
				my $linklabel = "Ganglia page for $host";
				#my $link = "http://gto-graphs.cadence.com/?c=Cadence&h=$host";
				my $link = "http://gto-graphs.cadence.com/?c=Cadence&amp;h=$host";
				$linkstring = "LINKLABEL=\"$linklabel\" LINK=\"$link\"";
				# sample graph link: http://gto-graphs.cadence.com//graph.php?g=load_report&z=medium&c=Cadence&h=cdsrld01&m=&r=hour&s=descending&hc=3&st=1169750310
			} elsif ($service =~ /cacti/i) {
				my $linklabel = "Cacti page";
				my $link = "http://gto-cacti.cadence.com/";
				$linkstring = "LINKLABEL=\"$linklabel\" LINK=\"$link\"";
			} elsif ($service =~ /(wiley|introscope)/i) {
				my $linklabel = "Wiley Introscope page";
				my $link = "http://appmon.cadence.com:8080/";
				$linkstring = "LINKLABEL=\"$linklabel\" LINK=\"$link\"";
			}
			print XML "\t\t\t<HOST NAME=\"$host\" WEIGHT=\"$default_weight\" $linkstring WARNING=\"$default_warning\" CRITICAL=\"$default_critical\"/>\n";
		}
		print XML "\t\t</SERVICE>\n";
	}
	print XML "\t</SERVICES>\n";
	print XML "</FOM_GROUP>\n";
}
print XML "<FOM_G_GROUP NAME=\"ALL HOST GROUPS\" WARNING=\"$default_warning\" CRITICAL=\"$default_critical\">\n";

#my $tmp = substr("GGroup_ALL_HOST_GROUPS",0,63);		# Nagios service name limit is 63 characters
print CSV "$FOM_host,$FOM_host_ipaddress,$FOM_passive_servicename,GGroup_ALL_HOST_GROUPS\n";
print XML "\t<GROUPS>\n";
foreach my $hostgroup (sort keys %{$monarch_hg_ref->{NAME}}) {
	print XML "\t\t<GROUP NAME=\"$hostgroup\"/>\n";
}
print XML "\t</GROUPS>\n";
print XML "</FOM_G_GROUP>\n";
print XML "</FOM>\n";
close XML;
close CSV;
