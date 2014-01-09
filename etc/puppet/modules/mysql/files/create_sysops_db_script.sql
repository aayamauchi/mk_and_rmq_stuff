create database sysops;
use sysops;
create table replicationTS (id int not null primary key auto_increment, timestamp int(11) unsigned not null);
grant all privileges on sysops.* to sysops@'%' identified by '********';
flush privileges;
