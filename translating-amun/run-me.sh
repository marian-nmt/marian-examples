#!/bin/bash

MARIAN=../..

# set chosen gpus
GPUS=0
if [ $# -ne 0 ]
then
    GPUS=$@
fi
echo Using gpus $GPUS

if [ ! -e $MARIAN/build/amun ]
then
    echo "amun is not installed in $MARIAN/build, you need to compile the toolkit first"
    exit 1
fi

if [ ! -e ../tools/moses-scripts ] || [ ! -e ../tools/sacreBLEU ]
then
    echo "missing tools in ../tools, you need to download them first"
    exit 1
fi

if [ ! -e "en-de/model.npz" ];
then
    wget -r -l 1 --cut-dirs=2 -e robots=off -nH -np -R index.html* http://data.statmt.org/rsennrich/wmt16_systems/en-de/
fi

if [ ! -e "data/newstest2015.ende.en" ]
then
    mkdir -p data
    ../tools/sacreBLEU/sacrebleu.py -t wmt15 -l en-de --echo src > data/newstest2015.ende.en
    ../tools/sacreBLEU/sacrebleu.py -t wmt15 -l en-de --echo ref > data/newstest2015.ende.de
fi

# translate test set with single model
cat data/newstest2015.ende.en | \
    # preprocess
    ../tools/moses-scripts/scripts/tokenizer/normalize-punctuation.perl -l en | \
    ../tools/moses-scripts/scripts/tokenizer/tokenizer.perl -l en -penn | \
    ../tools/moses-scripts/scripts/recaser/truecase.perl -model en-de/truecase-model.en | \
    # translate
    $MARIAN/build/amun -m en-de/model.npz -s en-de/vocab.en.json -t en-de/vocab.de.json \
    --mini-batch 50 --maxi-batch 1000 -d $GPUS --gpu-threads 1 -b 12 -n --bpe en-de/ende.bpe | \
    # postprocess
    ../tools/moses-scripts/scripts/recaser/detruecase.perl | \
    ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l de > data/newstest2015.single.out

# create configuration file for model ensemble
$MARIAN/build/amun -m en-de/model-ens?.npz -s en-de/vocab.en.json -t en-de/vocab.de.json \
    --mini-batch 1 --maxi-batch 1 -d $GPUS --gpu-threads 1 -b 12 -n --bpe en-de/ende.bpe \
    --relative-paths --dump-config > ensemble.yml

# translate test set with ensemble
cat data/newstest2015.ende.en | \
    # preprocess
    ../tools/moses-scripts/scripts/tokenizer/normalize-punctuation.perl -l en | \
    ../tools/moses-scripts/scripts/tokenizer/tokenizer.perl -l en -penn | \
    ../tools/moses-scripts/scripts/recaser/truecase.perl -model en-de/truecase-model.en | \
    # translate
    $MARIAN/build/amun -c ensemble.yml --gpu-threads 1 | \
    # postprocess
    ../tools/moses-scripts/scripts/recaser/detruecase.perl | \
    ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l de > data/newstest2015.ensemble.out

../tools/sacreBLEU/sacrebleu.py data/newstest2015.ende.de < data/newstest2015.single.out
../tools/sacreBLEU/sacrebleu.py data/newstest2015.ende.de < data/newstest2015.ensemble.out
