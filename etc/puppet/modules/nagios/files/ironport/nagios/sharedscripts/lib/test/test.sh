#!/bin/sh

# create test database
mysql -hlocalhost -uroot -proot -e "DROP DATABASE IF EXISTS testtclopslib;"
mysql -hlocalhost -uroot -proot -e "CREATE DATABASE testtclopslib;"
mysql -hlocalhost -uroot -proot testtclopslib < $(dirname $0)/testdb.sql

$(dirname $0)/testlib.sh -a -b param1 --testopt --testparam param2 --gnuopt=gnuoptvalue

# Local Variables:
# mode: sh
# coding: utf-8-unix
# comment-column: 0
# comment-start: "# "
# comment-end: ""
# End:
