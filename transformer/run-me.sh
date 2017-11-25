#!/bin/bash -v

MARIAN=../..

# set chosen gpus
GPUS=0
if [ $# -ne 0 ]
then
    GPUS=$@
fi
echo Using GPUs: $GPUS

if [ ! -e $MARIAN/build/marian ]
then
    echo "marian is not installed in ../../build, you need to compile the toolkit first"
    exit 1
fi

if [ ! -e ../tools/moses-scripts ] || [ ! -e ../tools/subword-nmt ] || [ ! -e ../tools/sacreBLEU ]
then
    echo "missing tools in ../tools, you need to download them first"
    exit 1
fi

if [ ! -e "data/corpus.en" ]
then
    ./scripts/download-files.sh
fi

mkdir -p model

# preprocess data
if [ ! -e "data/corpus.bpe.en" ]
then
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt13 -l en-de --echo src > data/valid.en
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt13 -l en-de --echo ref > data/valid.de

    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt14 -l en-de --echo src > data/test2014.en
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt15 -l en-de --echo src > data/test2015.en
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt16 -l en-de --echo src > data/test2016.en

    ./scripts/preprocess-data.sh
fi

# create common vocabulary
if [ ! -e "model/vocab.ende.yml" ]
then
    cat data/corpus.bpe.en data/corpus.bpe.de | $MARIAN/build/marian-vocab --max-size 36000 > model/vocab.ende.yml
fi

# train model
if [ ! -e "model/model.npz" ]
then
    $MARIAN/build/marian \
        --model model/model.npz --type transformer \
        --train-sets data/corpus.bpe.en data/corpus.bpe.de \
        --max-length 100 \
        --vocabs model/vocab.ende.yml model/vocab.ende.yml \
        --mini-batch-fit -w 10000 --maxi-batch 1000 \
        --early-stopping 10 \
        --valid-freq 5000 --save-freq 5000 --disp-freq 500 \
        --valid-metrics cross-entropy perplexity translation \
        --valid-sets data/valid.bpe.en data/valid.bpe.de \
        --valid-script-path ./scripts/validate.sh \
        --valid-translation-output data/valid.bpe.en.output --quiet-translation \
        --valid-mini-batch 64 \
        --beam-size 6 --normalize 0.6 \
        --log model/train.log --valid-log model/valid.log \
        --enc-depth 6 --dec-depth 6 \
        --transformer-heads 8 \
        --transformer-postprocess-emb d \
        --transformer-postprocess dan \
        --transformer-dropout 0.1 --label-smoothing 0.1 \
        --learn-rate 0.0003 --lr-warmup 16000 --lr-decay-inv-sqrt 16000 --lr-report \
        --optimizer-params 0.9 0.98 1e-09 --clip-norm 5 \
        --tied-embeddings-all \
        --devices $GPUS --sync-sgd --seed 1111 \
        --exponential-smoothing
fi

# find best model on dev set
ITER=`cat model/valid.log | grep translation | sort -rg -k8,8 -t' ' | cut -f4 -d' ' | head -n1`

# translate test sets
for prefix in test2014 test2015 test2016
do
    cat data/$prefix.bpe.en \
        | $MARIAN/build/marian-decoder -c model/model.npz.decoder.yml -m model/model.iter$ITER.npz -d $GPUS -b 12 -n \
        | sed 's/\@\@ //g' \
        | ../tools/moses-scripts/scripts/recaser/detruecase.perl \
        | ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l de \
        > data/$prefix.de.output
done

# calculate bleu scores on test sets
LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt14 -l en-de < data/test2014.de.output
LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt15 -l en-de < data/test2015.de.output
LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt16 -l en-de < data/test2016.de.output
