#!/usr/bin/env python

import os, sys, re

# This script prepare the Kaldi type data folder for Portugese ASR training using PTB_ASR002 dataset.
# audiosrc is used as AUDIO_merged_20121130, which is the latest updated Audio folder.
# Audios are converted from alaw format into mono PCM Sample frequency - 8000, wav format
# TRANSCRIPTIONS as trxn_src.

if len(sys.argv) < 5:
    print("USAGE : python local/prepare_data.py <AUDIO SRC FOLDER> <AUDIO SPLITS SRC> <TRANSCRIPTIONS SRC> <OUTPUT DATA DIR>")
    sys.exit()

audiosrc = os.path.abspath(sys.argv[1])
split_src = os.path.abspath(sys.argv[2])
trxn_src = os.path.abspath(sys.argv[3])
datadirin  = sys.argv[4]

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

splitnames = ["train", "dev", "test"]

trxn_scriptfile = open(trxn_src+'/scripted/script.map', 'r')
scriptmap = {}
for line in trxn_scriptfile:
    scriptid = line.partition(" ")[0]
    trxn = line.partition(" ")[2].strip().strip("\"")
    scriptmap[scriptid] = trxn
trxn_scriptfile.close()

for split in splitnames:
    datadir = datadirin + "/" + split
    os.system("mkdir -p " + datadir)
    wavscp = open(datadir + "/wav.scp", 'w')
    text = open(datadir+ "/text", 'w')
    utt2spk = open(datadir + "/utt2spk", 'w')
    with open(split_src + "/" + split, 'r') as data_split_src:
        for filepath in data_split_src:
            if filepath.split("/")[0] == "spontaneous":
                ln = filepath.strip()
                for file in os.listdir(audiosrc+'/'+ln):
                    fileid = file.split('.')[0]
                    with open(trxn_src+'/'+ ln +'/'+fileid + ".txt", 'r') as trxn_file:
                        wavscp.write(fileid + " " + audiosrc+"/"+ ln +"/"+fileid+".wav\n") 
                        textout = fileid
                        for linetext in trxn_file:
                            textout = textout + " " + normalize(linetext.strip())
                        text.write(textout + "\n")
                        utt2spk.write(fileid + " " + os.path.basename(ln) +"\n")
            else: # Case scripted rootpath
                ln = filepath.strip()
                for file in os.listdir(audiosrc+'/'+ln):
                    fileid = file.split('.')[0]
                    scriptid = fileid[5:7].upper()
                    wavscp.write(fileid + " " + audiosrc+"/"+ ln +"/"+fileid+".wav\n")
                    textout = fileid + " " + normalize(scriptmap[scriptid])
                    text.write(textout + "\n")
                    utt2spk.write(fileid + " " + os.path.basename(ln) +"\n")
    utt2spk.close()
    wavscp.close()
    text.close()
    os.system("utils/utt2spk_to_spk2utt.pl < " + datadir + "/utt2spk" + " > " + datadir + "/spk2utt") 
