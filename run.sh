#!/bin/bash
#
# Copyright 2020 
# E2E recipe for Children's speech ASR

stage=0
train_stage=-20
expdir=exp
srclexicon=SBL_SpeechEngineerExercise_Generic/cmudict.0.7a.lc
srcdata=SBL_SpeechEngineerExercise_Generic/SpeechDataBase
mfccdir=`pwd`/mfcc

. ./cmd.sh

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

set -eou pipefail

srilm_opts="-subset -order 3"

if [ $stage -le 0 ]; then
  mkdir -p data/local $expdir
  local/prepare_data.sh $srcdata local/splits data 
  local/prepare_dict.sh $srclexicon
  steps/dict/train_g2p_phonetisaurus.sh $srclexicon $expdir/g2p
fi

if [ $stage -le 1 ]; then
  dict_dir=data/local/dict
  mkdir -p $dict_dir
  cp data/local/dict_combined//{extra_questions,nonsilence_phones,silence_phones,optional_silence}.txt $dict_dir

  echo 'Gathering missing words...'
  lexicon=data/local/dict_combined/lexicon.txt
  g2p_tmp_dir=data/local/g2p
  mkdir -p $g2p_tmp_dir

  # awk command from http://stackoverflow.com/questions/2626274/print-all-but-the-first-three-columns
  cat data/train/text | \
    local/count_oovs.pl $lexicon | \
    cut -f 4- -d " " | \
    perl -ape 's/\s/\n/g;' | \
  sed "/^[[:space:]]*$/d" |sort | uniq > $g2p_tmp_dir/missing.txt
  cat $g2p_tmp_dir/missing.txt | \
    grep "^[a-zA-Z'-]*$" | grep "[a-zA-Z]" > $g2p_tmp_dir/missing_onlywords.txt

  steps/dict/apply_g2p_phonetisaurus.sh --nbest 1 $g2p_tmp_dir/missing_onlywords.txt $expdir/g2p $expdir/g2p/oov_lex || exit 1;
  cp $expdir/g2p/oov_lex/lexicon.lex $g2p_tmp_dir/missing_lexicon.txt

  extended_lexicon=$dict_dir/lexicon.txt
  echo "Adding new pronunciations to get extended lexicon $extended_lexicon"
  cut -f 1,3 -d"	" $g2p_tmp_dir/missing_lexicon.txt | sed "/^[[:space:]]*$/d" |sort | uniq | grep -v "[[:space:]]$" > $extended_lexicon
  cat $lexicon >> $extended_lexicon.2
  sort $extended_lexicon.2 | uniq > $extended_lexicon
fi

if [ $stage -le 2 ]; then  
  utils/prepare_lang.sh data/local/dict "<unk>" data/local/lang data/lang
  mkdir -p data/local/lm
  cut -f 2- -d " " data/train/text | sed "s:\[noise\]::g" | \
	  sed "s:\[sil\]::g" | sed "s:<unk>::g" > data/local/lm/text
  ngram-count -wbdiscount -text data/local/lm/text -lm data/local/lm/srilm.3g.gz
  ngram-count -wbdiscount -order 2 -text data/local/lm/text -lm data/local/lm/srilm.2g.gz
  utils/format_lm_sri.sh --srilm-opts "-subset -order 2" \
	  data/lang data/local/lm/srilm.2g.gz \
	  data/local/dict/lexicon.txt data/lang_test_bg
  utils/format_lm_sri.sh --srilm-opts "$srilm_opts" \
    data/lang data/local/lm/srilm.3g.gz \
    data/local/dict/lexicon.txt data/lang_test

  for f in train dev test ; do
    steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" data/$f $expdir/make_mfcc/$f $mfccdir || exit 1;
    steps/compute_cmvn_stats.sh data/$f $expdir/make_mfcc/$f $mfccdir
  done
  utils/fix_data_dir.sh data/train
fi

if [ $stage -le 3 ]; then
  steps/train_mono.sh --nj 4 --cmd "$train_cmd" \
    data/train data/lang $expdir/mono0a

  steps/align_si.sh --nj 4 --cmd "$train_cmd" \
    data/train data/lang $expdir/mono0a $expdir/mono0a_ali || exit 1;

  (
    utils/mkgraph.sh data/lang_test $expdir/mono0a $expdir/mono0a/graph || exit 1;
    steps/decode.sh --nj 2 --cmd "$decode_cmd" --config conf/decode.config \
      $expdir/mono0a/graph data/dev $expdir/mono0a/decode_dev || exit 1;
   )&

  steps/train_deltas.sh --cmd "$train_cmd" \
    2000 15000 data/train data/lang $expdir/mono0a_ali $expdir/tri2 || exit 1;

  (
    utils/mkgraph.sh data/lang_test $expdir/tri2 $expdir/tri2/graph || exit 1;
    steps/decode.sh --nj 2 --cmd "$decode_cmd" --config conf/decode.config \
      $expdir/tri2/graph data/dev $expdir/tri2/decode_dev || exit 1;
   )&
fi

if [ $stage -le 4 ]; then
  steps/align_si.sh --nj 4 --cmd "$train_cmd" \
    data/train data/lang $expdir/tri2 $expdir/tri2_ali || exit 1;

# Train tri3a, which is LDA+MLLT, on 100k data.
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
   --splice-opts "--left-context=3 --right-context=3" \
   2500 25000 data/train data/lang $expdir/tri2_ali $expdir/tri3a || exit 1;
  (
    utils/mkgraph.sh data/lang_test $expdir/tri3a $expdir/tri3a/graph || exit 1;
    steps/decode.sh --nj 2 --cmd "$decode_cmd" --config conf/decode.config \
     $expdir/tri3a/graph data/dev $expdir/tri3a/decode_dev || exit 1;
  )&
fi

if [ $stage -le 5 ]; then
# Next we'll use fMLLR and train with SAT (i.e. on
# fMLLR features)
  steps/align_fmllr.sh --nj 4 --cmd "$train_cmd" \
    data/train data/lang $expdir/tri3a $expdir/tri3a_ali || exit 1;

  steps/train_sat.sh  --cmd "$train_cmd" \
    3500 40000 data/train data/lang $expdir/tri3a_ali  $expdir/tri4a || exit 1;

  (
    utils/mkgraph.sh data/lang_test $expdir/tri4a $expdir/tri4a/graph
    steps/decode_fmllr.sh --nj 2 --cmd "$decode_cmd" --config conf/decode.config \
      $expdir/tri4a/graph data/dev $expdir/tri4a/decode_dev
  ) &

  steps/align_fmllr.sh \
     --boost-silence 0.5 --nj 4 --cmd "$train_cmd" \
     data/train data/lang $expdir/tri4a $expdir/tri4a_ali
fi

if [ $stage -le 6 ]; then
    local/nnet/run_dnn.sh --stage $stage --train-stage $train_stage || exit 1;
fi

exit 0;