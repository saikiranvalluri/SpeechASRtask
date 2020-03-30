#!/usr/bin/env python

import os, sys, re

if len(sys.argv) < 3:
    print("USAGE : python local/prepare_data.py <TRANSCRIPTIONS SRC LM text> <OUTPUT LM text>")
    sys.exit()

basetrxns = open(sys.argv[1], 'r')
LMtext = open(sys.argv[2], 'w')

punct_regex = re.compile('[()*;:"!&{}?,.\[\]]')

def normalize(utt):
    utt = re.sub(punct_regex, "", utt)  # replace punctuation symbols
    utt = utt.replace('<pau>', ' [sil] ') \
             .replace('<long>', ' [sil] ') \
             .replace('<br>', ' [noise] ') \
             .replace('<pron>', ' <unk> ') \
             .replace('<bn>', ' [noise] ') \
             .replace('<bs>', ' [noise] ')
    return utt

for line in basetrxns:
    textout = normalize(line.strip())
    LMtext.write(textout + "\n")

basetrxns.close()
LMtext.close()
