#!/bin/bash

###########################################################################################
# This script was copied from egs/swbd/s5c/local/swbd1_prepare_dict.sh
# The source commit was e435334b4b7bb9eaf28764f37bb44a825da320fc
###########################################################################################

# To be run from one directory above this script.

. ./path.sh

#check existing directories
[ $# != 1 ] && echo "Usage: local/swbd1_data_prep.sh <src lexicon path>" && exit 1;

dir=data/local/dict_combined/
mkdir -p $dir
srcdict=$1

[ ! -f "$srcdict" ] && echo "$0: No such file $srcdict" && exit 1;

rm -f $dir/lexicon0.txt
cp $srcdict $dir/lexicon0.txt || exit 1;
chmod +w $dir/lexicon0.txt

#(2a) Dictionary preparation:
# Pre-processing (remove comments)
grep -v '^#' $dir/lexicon0.txt | awk 'NF>0' | sort > $dir/lexicon1.txt || exit 1;

cat $dir/lexicon1.txt | awk '{ for(n=2;n<=NF;n++){ phones[$n] = 1; }} END{for (p in phones) print p;}' | \
  grep -v sil > $dir/nonsilence_phones.txt  || exit 1;

( echo sil; echo spn; echo nsn; ) > $dir/silence_phones.txt

echo sil > $dir/optional_silence.txt

# No "extra questions" in the input to this setup, as we don't
# have stress or tone.
echo -n >$dir/extra_questions.txt

# Add to the lexicon the silences, noises etc.
# Add single letter lexicon
# The original swbd lexicon does not have precise single letter lexicion
# e.g. it does not have entry of W
( echo '[sil] sil'; echo '[noise] nsn'; \
  echo '<unk> spn' ) \
  | cat - $dir/lexicon1.txt  > $dir/lexicon2.txt || exit 1;

pushd $dir >&/dev/null
ln -sf lexicon2.txt lexicon.txt # This is the final lexicon.
popd >&/dev/null
rm $dir/lexiconp.txt 2>/dev/null
echo Prepared input dictionary and phone-sets for portugese.
