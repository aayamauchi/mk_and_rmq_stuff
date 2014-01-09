#!/usr/bin/python

import sys
import string
import os

if __name__ == '__main__':
    previous_line = ""
    cur_line=""
    lines = sys.stdin.readlines()
    for i in range(len(lines)):
        if i == 0:
            continue
        if lines[i][0] == ' ':
            cur_line = cur_line + str(lines[i][:-1])
        else:
            print cur_line
            cur_line=lines[i][:-1]

