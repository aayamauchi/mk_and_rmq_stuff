#!/usr/local/bin/bash

/usr/bin/find /tmp \( -maxdepth 1 -a -name 'update-repl*pid' -a -mmin +10 \) -delete 
