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

python local/prepare_data_corpus.py $srcdatabase/speech $splitsfilepath $srcdatabase/trans $outputpath

exit 0;
