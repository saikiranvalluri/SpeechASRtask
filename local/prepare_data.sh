#!/usr/bin/env bash

stage=0

. utils/parse_options.sh

srcdatabase=$1
splitsfilepath=$2
outputpath=$3

if [ $# -eq 0 ]; then
  echo "$0 <source datapath> <path for train list> <output path>"
  echo " e.g.: $0 SBL_SpeechEngineerExercise_Generic/SpeechDataBase local/splits data"
  exit 1;
fi

cat $srcdatabase/trans/spontaneous/*/*/*/*.txt > data/train_LM_init.txt
cut -f 2- -d " " $srcdatabase/trans/scripted/script.map | sed "s:\"::g" >> data/train_LM_init.txt
python local/prepare_data_corpus.py $srcdatabase/speech $splitsfilepath $srcdatabase/trans $outputpath
python local/prepare_LMdata.py data/train_LM_init.txt data/train_LM.txt

exit 0;
