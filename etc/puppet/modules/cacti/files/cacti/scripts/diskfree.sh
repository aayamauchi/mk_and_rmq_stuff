#!/bin/sh

PATH=/bin:/usr/bin
df -k $1 | grep -v Filesystem| awk '{printf "megabytes:" $4 " percent:" int($5)}'
