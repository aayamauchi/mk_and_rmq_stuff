#!/bin/sh

echo "$*" >> /tmp/wrap.out
$* | tee -a /tmp/wrap.out

