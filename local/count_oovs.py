#!/usr/bin/env python3

import os, sys

if len(sys.argv) < 4:
    print("USAGE : count_oovs.py <inout file> <lexicon> <oovlistout>")
    sys.exit()

fin = open(sys.argv[1], 'r', encoding="utf-8", errors="ignore")
fdict=open(sys.argv[2], 'r', encoding="utf-8", errors="ignore")
oovfile = open(sys.argv[3], 'w', encoding="utf-8", errors="ignore")

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
