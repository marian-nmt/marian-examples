#!/bin/bash -v

# suffix of target language files
SRC=en
TRG=de

# path to moses decoder: https://github.com/moses-smt/mosesdecoder
mosesdecoder=../tools/moses-scripts

# path to subword segmentation scripts: https://github.com/rsennrich/subword-nmt
subword_nmt=../tools/subword-nmt

# tokenize

prefix=news.2016

cat data/$prefix.$TRG \
    | $mosesdecoder/scripts/tokenizer/normalize-punctuation.perl -l $TRG \
    | $mosesdecoder/scripts/tokenizer/tokenizer.perl -a -l $TRG > data/$prefix.tok.$TRG

$mosesdecoder/scripts/recaser/truecase.perl -model model/tc.$TRG < data/$prefix.tok.$TRG > data/$prefix.tc.$TRG

$subword_nmt/apply_bpe.py -c model/$SRC$TRG.bpe < data/$prefix.tc.$TRG > data/$prefix.bpe.$TRG
