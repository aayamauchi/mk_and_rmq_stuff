%define _requires_exceptions pear(default.php)

Name:		check-mk
Version:	1.2.2p2
Release:	3%{?dist}.%{cisco_release}.cisco
Summary:	A new general purpose Nagios-plugin for retrieving data
Group:		Applications/Internet
License:	GPLv2 and GPLv3
URL:		http://mathias-kettner.de/check_mk
Source:		http://mathias-kettner.de/download/check_mk-%{version}.tar.gz
Packager: Alex Yamauchi <ayamauch@cisco.com>

%if 0%{?rhel}
Requires:	mod_python
%endif
Source1:	First-Installation.txt
Source2:	defaults
Source3:	defaults.py

Patch100:	cisco_check-mk_xinetd-fixes.patch

AutoReq:	0
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires: gcc
BuildRequires: gcc-c++

%description
check-mk is a general purpose Nagios-plugin for retrieving data. It adopts a
new approach for collecting data from operating systems and network components.
It obsoletes NRPE, check_by_ssh, NSClient, and check_snmp and it has many
benefits, the most important are a significant reduction of CPU usage on
the Nagios host and an automatic inventory of items to be checked on hosts.

%package utils
Summary: General purpose utilities
Group: Applications/System

%description utils
These are general-purpose system utils built with the check_mk sources.
Some or all of the component packages need these tools for certain
functionality, and other software my need these tools for purposes
completely unrelated to monitoring.

%package agent
Summary:	The check-mk's Agent
Group:		Applications/Internet

%description agent
This package contains the check-mk's agent. Install the following
agent on all the machines you plan to monitor with check-mk.

%package docs
Summary:	The check-mk's documentation
Group:		Applications/Internet
AutoReq:	0
%if 0%{?rhel}
AutoProv:	0
%endif

%description docs
This package contains the check-mk's documentation files.

%package livestatus
Summary:	The check-mk's Livestatus
Group:		Applications/Internet

%description livestatus
This package contains livestatus, the check-mk's plugin for
accessing the relevant Nagios files being responsible of
listing the hosts and services status.

%package multisite
Summary:	The check-mk's Multisite
Group:		Applications/Internet
Requires:	%{name} = %{version}-%{release}

%description multisite
This package contains the check-mk's web interface aka WATO.

%prep
%setup -q -n check_mk-%{version}
tar xf agents.tar.gz

%patch100 -p1

%build
rm -f waitmax
make waitmax

%install

# Agent's installation

install -d -m 755 %{buildroot}%{_bindir}
install -m 755 check_mk_agent.linux %{buildroot}%{_bindir}/check_mk_agent

# Waitmax's binary
install -m 755 waitmax %{buildroot}%{_bindir}/waitmax

install -d -m 755 %{buildroot}%{_datadir}/check-mk-agent
install -d -m 755 %{buildroot}%{_datadir}/check-mk-agent/plugins
install -d -m 755 %{buildroot}%{_datadir}/check-mk-agent/local

install -m 644 xinetd.conf %{buildroot}%{_datadir}/check-mk-agent/xinetd.conf
install -m 644 xinetd_caching.conf %{buildroot}%{_datadir}/check-mk-agent/xinetd_caching.conf

install -m 644 plugins/mk_logwatch %{buildroot}%{_datadir}/check-mk-agent/plugins
install -m 644 plugins/j4p_performance %{buildroot}%{_datadir}/check-mk-agent/plugins
install -m 644 plugins/mk_oracle %{buildroot}%{_datadir}/check-mk-agent/plugins
install -m 644 plugins/sylo %{buildroot}%{_datadir}/check-mk-agent/plugins

install -d -m 755 %{buildroot}%{_sysconfdir}/check-mk-agent
install -m 644 logwatch.cfg %{buildroot}%{_sysconfdir}/check-mk-agent

perl -pi \
    -e 's|MK_LIBDIR="/usr/lib/check_mk_agent"|MK_LIBDIR="%{_datadir}/check-mk-agent"|;' \
    -e 's|MK_CONFDIR="/etc/check_mk"|MK_CONFDIR="%{_sysconfdir}/check-mk-agent"|;' \
    %{buildroot}%{_bindir}/check_mk_agent

# Server, livestatus and other modules installation

DESTDIR=%{buildroot} ./setup.sh --yes

install -d -m 755 %{buildroot}%{_datadir}/check-mk-livestatus

install -m 644 xinetd_livestatus.conf %{buildroot}%{_datadir}/check-mk-livestatus/xinetd.conf

# Some needed tweaks to modify setup.sh's defaults.

# /etc/apache2/conf.d --> /etc/httpd/conf.d
mkdir -p %{buildroot}%{_sysconfdir}/httpd/conf.d/
mv %{buildroot}%{_sysconfdir}/apache2/conf.d/zzz_check_mk.conf %{buildroot}%{_sysconfdir}/httpd/conf.d/zzz_check_mk.conf
rm -rf %{buildroot}%{_sysconfdir}/apache2/

# Install the First-Installation.txt file
install -m 644 %{SOURCE1} %{buildroot}%{_sysconfdir}/check_mk

# Make sure all the scripts into /usr/share/check_mk/* and /usr/share/check-mk-agent/* are executable.
for file in %{buildroot}%{_datadir}/check_mk/checks/* ; do
   chmod -R a+x $file
done

for file in %{buildroot}%{_datadir}/check-mk-agent/plugins/* ; do
   chmod a+x $file
done

# Fix a few more permissions
chmod a+x %{buildroot}%{_datadir}/check_mk/agents/hpux/hpux_statgrab
chmod a+x %{buildroot}%{_datadir}/check_mk/agents/hpux/hpux_lunstats
chmod a+x %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.openbsd
chmod a+x %{buildroot}%{_datadir}/check_mk/agents/plugins/db2_mem.sh
chmod a+x %{buildroot}%{_datadir}/check_mk/modules/snmp.py
chmod a+x %{buildroot}%{_datadir}/check_mk/modules/packaging.py
chmod a+x %{buildroot}%{_datadir}/check_mk/modules/agent_simulator.py
chmod a+x %{buildroot}%{_datadir}/check_mk/modules/notify.py
chmod a+x %{buildroot}%{_datadir}/check_mk/modules/automation.py
chmod a+x %{buildroot}%{_datadir}/check_mk/notifications/debug

# Web app files are not intended to be run, remove the shebang
# TODO: ask upstream to do the same
for file in `find %{buildroot}%{_datadir}/check_mk/web -name '*.py'`; do
 sed -i '1{\@^#!/usr/bin/python@d}' $file
done

# Copy the check_mk_templates.cfg from the example file and remove the file installed
# on the /etc/nagios/objects directory.
mkdir -p %{buildroot}%{_sysconfdir}/nagios/conf.d/
cp -r %{buildroot}%{_datadir}/check_mk/check_mk_templates.cfg %{buildroot}%{_sysconfdir}/nagios/conf.d/check_mk_templates.cfg
rm -rf %{buildroot}%{_sysconfdir}/nagios/objects/check_mk_templates.cfg

# Fix the path for the Nagios plugins
sed -i 's|/usr/lib/nagios/plugins|%{_libdir}/nagios/plugins|' \
  %{buildroot}%{_sysconfdir}/nagios/conf.d/check_mk_templates.cfg

# Remove the auto-generated defaults file and replace it with a customized version
rm -rf %{buildroot}%{_datadir}/check_mk/modules/defaults
install -m 644 %{SOURCE2} %{buildroot}%{_datadir}/check_mk/modules/

# Do the same for defaults.py
rm -rf %{buildroot}%{_datadir}/check_mk/web/htdocs/defaults.py
install -m 644 %{SOURCE3} %{buildroot}%{_datadir}/check_mk/web/htdocs/

# Remove other operating systems agents, we definitely don't need them on this package.
rm -rf %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.aix
rm -rf %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.freebsd
rm -rf %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.hpux
rm -rf %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.macosx
rm -rf %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.netbsd
rm -rf %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.openbsd
rm -rf %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.openvms
rm -rf %{buildroot}%{_datadir}/check_mk/agents/check_mk_agent.solaris

# Remove Windows files.
rm -rf %{buildroot}%{_docdir}/check_mk/windows/
rm -rf %{buildroot}%{_datadir}/check_mk/agents/windows/

# Remove waitmax and its leftarounds from the wrong directory, the binary is being
# built and installed into the check-mk-agent's package already.
rm %{buildroot}%{_datadir}/check_mk/agents/waitmax
rm %{buildroot}%{_datadir}/check_mk/agents/waitmax.c

# Remove the packages directory.
rm -rf %{buildroot}%{_localstatedir}/lib/check_mk/packages/

# Make sure an /etc/check_mk/conf.d/wato directory is created for WATO to work properly
mkdir -p %{buildroot}%{_sysconfdir}/check_mk/conf.d/wato

%if %{_lib} == lib64

mkdir -p %{buildroot}%{_prefix}/lib64/check_mk
mv %{buildroot}%{_prefix}/lib/check_mk/livecheck %{buildroot}%{_prefix}/lib64/check_mk/
mv %{buildroot}%{_prefix}/lib/check_mk/livestatus.o %{buildroot}%{_prefix}/lib64/check_mk/
rmdir %{buildroot}%{_prefix}/lib/check_mk

%endif

%files
%{_bindir}/cmk
%{_bindir}/check_mk
%config(noreplace) %{_sysconfdir}/check_mk/main.mk
%config(noreplace) %{_sysconfdir}/check_mk/main.mk-1.2.2p2
%{_sysconfdir}/check_mk/First-Installation.txt
%{_sysconfdir}/check_mk/conf.d
%{_datadir}/check_mk/agents
%{_datadir}/check_mk/modules
%{_datadir}/check_mk/checks
%{_datadir}/check_mk/pnp-templates
%{_datadir}/check_mk/notifications
%{_datadir}/check_mk/check_mk_templates.cfg
%config(noreplace) %{_sysconfdir}/httpd/conf.d/zzz_check_mk.conf
%config(noreplace) %{_sysconfdir}/nagios/conf.d/check_mk_templates.cfg
%attr(755, nagios, nagios) %{_localstatedir}/lib/check_mk/*
%doc COPYING ChangeLog AUTHORS

%files utils
%{_bindir}/waitmax
%{_bindir}/unixcat
%{_bindir}/mkp

%files agent
%{_bindir}/check_mk_agent
%{_datadir}/check-mk-agent
%config(noreplace) %{_sysconfdir}/check-mk-agent
%doc COPYING

%files docs
%doc %{_docdir}/check_mk

%files multisite
%{_datadir}/check_mk/web
%config(noreplace) %{_sysconfdir}/check_mk/multisite.mk
%config(noreplace) %{_sysconfdir}/check_mk/multisite.mk-1.2.2p2
%{_sysconfdir}/check_mk/multisite.d
%attr(660, apache, nagios) %{_sysconfdir}/check_mk/conf.d/wato

%files livestatus
%{_libdir}/check_mk/*
%{_datadir}/check-mk-livestatus

%changelog
* Thu Jan 09 2014 Alex Yamauchi <ayamauch@cisco.com> - 1.2.2p2-3.*.1.cisco
- Branching a custom build off of the EPEL release 3 of check-mk
  version 1.2.2p2 packaging (1.2.2p2-3).  The major issues addressed
	by the rebuild:
    - fixed a bunch of misspecified package dependencies,
		- added the "-utils" subpackage to resolve the shared dependencies on
		  tools, such "unixcat" in a sane way,
		- removed the live xinetd delivery for check-mk-agent, since it
		  results in multiple definitions after an update (moved to shared),
		- added the default xinetd configuration for the livestatus module.

* Wed Oct 02 2013 Andrea Veri <averi@fedoraproject.org> - 1.2.2p2-3
- Start building the debuginfo package again, seems the issue is
  related to the buildarch being noarch which turns all the subpackages
  to be noarch themselves. Also drop the noarch bits everywhere so
  that the needed sources are built for all the archs.

* Wed Oct 02 2013 Andrea Veri <averi@fedoraproject.org> - 1.2.2p2-2
- Make sure an /etc/check_mk/conf.d/wato directory is created for WATO
  to work properly. (BZ: #987863)
- Define the RPM_BUILD_ROOT or the build will fail on a RHEL 5 mock.
- Make sure the livestatus files are installed correctly by using the
  _libdir macro.
- Stop shipping a debuginfo package, seems debug files are not installed
  and detected properly on EL5.

* Sat Aug 31 2013 Andrea Veri <averi@fedoraproject.org> - 1.2.2p2-1
- New upstream release.

* Thu Aug 29 2013 Andrea Veri <averi@fedoraproject.org> - 1.2.2-5
- Make sure the waitmax binary gets built. Also thanks to John Reddy
  for his initial work on this. (BZ: #982769)
- Add an if statement for RHEL and make sure auto provides are not set
  automatically. (BZ #985285)
- Requires set to mod_python on RHEL, no mod_wsgi migration yet on EPEL. (BZ: #987852)
- Fix the perl command that was doing the needed substitution on the 
  /usr/bin/check_mk_agent's configuration directories. Thanks Brainslug for the
  report. (BZ: #989793)
- In addition to a customized 'defaults' file, add a defaults.py accordingly. (BZ: #987859)

* Sun Apr 28 2013 Andrea Veri <averi@fedoraproject.org> 1.2.2-4%{?dist}
- Make sure the Nagios library path on the check_mk_templates.cfg file
  is correct on both x86_64 and i686 systems.

* Sat Apr 27 2013 Andrea Veri <averi@fedoraproject.org> 1.2.2-3%{?dist}
- Change check-mk-agent's binary name to check_mk_agent to match xinetd's file. (BZ: #956489)
- Remove other operating systems agents, we definitely don't need them on this package.
- Make sure that check_mk_templates gets shipped into /etc/nagios/conf.d. (BZ: #956492)
- Don't ship the auto-generated defaults file, but provide it with our customizations. This actually
  fixes BZ: #956496 since we modify the checkresults path to be the same as the one provided
  by Nagios itself, thus no need to create an additional directory.

* Wed Apr 10 2013 Andrea Veri <averi@fedoraproject.org> 1.2.2-2%{?dist}
- Remove the extra % on the Requires field for multisite.

* Tue Apr 09 2013 Andrea Veri <averi@fedoraproject.org> 1.2.2-1%{?dist}
- New upstream release.
- Added a depends on Nagios.
- Start shipping the docs, multisite, livestatus packages.
- Make sure the check_mk_templates.cfg file gets installed on the relevant 
  Nagios directory.
- Add the missing licenses.
- Switch package name to check-mk.
- Livestatus build has been fixed, switch the build/install system to use
  upstream's setup.sh.
- Include an handy First-Installation.txt file with instructions about what
  steps you should follow right after installing the check-mk's package.

* Fri Apr 05 2013 Andrea Veri <averi@fedoraproject.org> 1.2.0p4-1%{?dist}
- First package release.

