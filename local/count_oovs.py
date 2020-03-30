#!/usr/bin/env python3

import os, sys

if len(sys.argv) < 4:
    print("USAGE : count_oovs.py <inout file> <lexicon> <oovlistout>")
    sys.exit()

fin = open(sys.argv[1], 'r')
fdict=open(sys.argv[2], 'r')
oovfile = open(sys.argv[3], 'w')

lexicon=[]
for line in fdict:
    lexicon.append(line.split()[0])

for line in fin:
    for word in line.split():
        if not word in lexicon:
            oovfile.write(word+"\n")

fin.close()
fdict.close()
oovfile.close()
