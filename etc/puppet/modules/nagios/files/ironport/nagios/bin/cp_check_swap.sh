#!/bin/sh

for host in `cat $1`; do
	echo "Now working on $host."
	scp ~/libexec-4x/check_swap $host:
	ssh $host 'rm -f libexec/check_swap && mv check_swap libexec'
	echo ""
done

