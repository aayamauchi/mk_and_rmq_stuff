# Set threading model

update host set device_threads=4 where hostname like '%esx%';
update host set device_threads=8 where hostname like '%-vc-%';
update host set device_threads=1 where hostname like '%smtpi%';
update host set device_threads=1 where hostname like '%iphmx%';
update host set device_threads=2 where hostname like '%db%';
update host set device_threads=2 where hostname like '%sql%';

# poller_id in /usr/share/cacti/spine.id

# deprecated pollers (5, 6, 7): use 5 for any server that should not be polled
update host set poller_id=5 where hostname like '%soma%' or notes like '%Location:soma%';
update host set poller_id=5 where hostname like '%mega%' or notes like '%Location:mega%';
update host set poller_id=5 where hostname like '%coma%' or notes like '%Location:coma%';

# vega pollers
update host set poller_id=1 where poller_id=0;
update host set poller_id=1 where hostname like '%vega%' or notes like '%Location:vega%';
update host set poller_id=1 where id=1312 or id=1335 or id=1336 or id=1337 or id=1338 or id=1339;
update host set poller_id=1 where id=1204 or id=1198 or id=1489 or id=1198 or id=2192 or id=1457;
update host set poller_id=1 where id=1340;
update host set poller_id=1 where poller_id between 1 and 4 and id%4=0;
update host set poller_id=2 where poller_id between 1 and 4 and id%4=1;
update host set poller_id=3 where poller_id between 1 and 4 and id%4=2;
update host set poller_id=4 where poller_id between 1 and 4 and id%4=3;

# aer01 pollers
update host set poller_id=8 where hostname like '%aer01%' or notes like '%Location:aer01%';
update host set poller_id=9 where poller_id=8 and id%2=1;

# ld5 pollers
update host set poller_id=10 where hostname like '%ld5%' or notes like '%Location:ld5%';
update host set poller_id=11 where poller_id=10 and id%2=1;

# sv4 pollers
update host set poller_id=40 where poller_id=41;
update host set poller_id=40 where hostname like '%sv4%' or notes like '%Location:sv4%';
update host set poller_id=40 where hostname like '%sv2%' or notes like '%Location:sv2%';
update host set poller_id=40 where hostname like '%atlas%';
update host set poller_id=40 where id=1630 or id=1689 or id=1613;
update host set poller_id=41 where poller_id=40 and id%4=1;
update host set poller_id=42 where poller_id=40 and id%4=2;
update host set poller_id=43 where poller_id=40 and id%4=3;

# nap5 pollers
update host set poller_id=50 where hostname like '%nap5%' or notes like '%Location:nap5%';
update host set poller_id=51 where poller_id=50 and id%4=1;
update host set poller_id=52 where poller_id=50 and id%4=2;
update host set poller_id=53 where poller_id=50 and id%4=3;

# DataCenter Firewalls (see MONOPS-1548 and related tickets for details)
update host set poller_id=1 where notes like 'fw-brd%' and description like '%Firewall';

# Two update statements after this line.  Add *nothing* after these lines.

update poller_item, host set poller_item.poller_id=host.poller_id where poller_item.host_id=host.id;
update host set ping_method=1 where hostname like '%iphmx.com' and (notes like '%sv2%' or notes like '%nap5%');
