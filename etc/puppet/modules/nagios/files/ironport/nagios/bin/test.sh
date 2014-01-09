#!/usr/local/bin/bash

cat /dev/random >> /dev/null &

echo $!

