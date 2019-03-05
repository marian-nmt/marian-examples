#!/bin/bash -v

MARIAN=../../build

# if we are in WSL, we need to add '.exe' to the tool names
if [ -e "/bin/wslpath" ]
then
    EXT=.exe
fi

MARIAN_TRAIN=$MARIAN/marian$EXT
MARIAN_DECODER=$MARIAN/marian-decoder$EXT
MARIAN_VOCAB=$MARIAN/marian-vocab$EXT
MARIAN_SCORER=$MARIAN/marian-scorer$EXT

# set chosen gpus
GPUS=0
if [ $# -ne 0 ]
then
    GPUS=$@
fi
echo Using GPUs: $GPUS


WORKSPACE=9500
N=4
EPOCHS=8
B=12

if [ ! -e $MARIAN_TRAIN ]
then
    echo "marian is not installed in $MARIAN, you need to compile the toolkit first"
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
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt16 -l en-de --echo src > data/valid.en
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt16 -l en-de --echo ref > data/valid.de

    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt14 -l en-de --echo src > data/test2014.en
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt15 -l en-de --echo src > data/test2015.en
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt16 -l en-de --echo src > data/test2016.en
    LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt17 -l en-de --echo src > data/test2017.en

    ./scripts/preprocess-data.sh
fi

if [ ! -e "data/news.2016.de" ]
then
    ./scripts/download-files-mono.sh
fi

if [ ! -e "data/news.2016.bpe.de" ]
then
    ./scripts/preprocess-data-mono.sh
fi

# create common vocabulary
if [ ! -e "model/vocab.ende.yml" ]
then
    cat data/corpus.bpe.en data/corpus.bpe.de | $MARIAN_VOCAB --max-size 36000 > model/vocab.ende.yml
fi

# train model
mkdir -p model.back
if [ ! -e "model.back/model.npz.best-translation.npz" ]
then
    $MARIAN_TRAIN \
        --model model.back/model.npz --type s2s \
        --train-sets data/corpus.bpe.de data/corpus.bpe.en \
        --max-length 100 \
        --vocabs model/vocab.ende.yml model/vocab.ende.yml \
        --mini-batch-fit -w 3500 --maxi-batch 1000 \
        --valid-freq 10000 --save-freq 10000 --disp-freq 1000 \
        --valid-metrics ce-mean-words perplexity translation \
        --valid-script-path "bash ./scripts/validate.en.sh" \
        --valid-translation-output data/valid.bpe.de.output --quiet-translation \
        --valid-sets data/valid.bpe.de data/valid.bpe.en \
        --valid-mini-batch 64 --beam-size 12 --normalize=1 \
        --overwrite --keep-best \
        --early-stopping 5 --after-epochs 10 --cost-type=ce-mean-words \
        --log model.back/train.log --valid-log model.back/valid.log \
        --tied-embeddings-all --layer-normalization \
        --devices $GPUS --seed 1111 \
        --exponential-smoothing
fi

if [ ! -e "data/news.2016.bpe.en" ]
then
    $MARIAN_DECODER \
      -c model.back/model.npz.best-translation.npz.decoder.yml \
      -i data/news.2016.bpe.de \
      -b 6 --normalize=1 -w 2500 -d $GPUS \
      --mini-batch 64 --maxi-batch 100 --maxi-batch-sort src \
      --max-length 200 --max-length-crop \
      > data/news.2016.bpe.en
fi

if [ ! -e "data/all.bpe.en" ]
then
    cat data/corpus.bpe.en data/corpus.bpe.en data/news.2016.bpe.en > data/all.bpe.en
    cat data/corpus.bpe.de data/corpus.bpe.de data/news.2016.bpe.de > data/all.bpe.de
fi

for i in $(seq 1 $N)
do
  mkdir -p model/ens$i
  # train model
    $MARIAN_TRAIN \
        --model model/ens$i/model.npz --type transformer \
        --train-sets data/all.bpe.en data/all.bpe.de \
        --max-length 100 \
        --vocabs model/vocab.ende.yml model/vocab.ende.yml \
        --mini-batch-fit -w $WORKSPACE --mini-batch 1000 --maxi-batch 1000 \
        --valid-freq 5000 --save-freq 5000 --disp-freq 500 \
        --valid-metrics ce-mean-words perplexity translation \
        --valid-sets data/valid.bpe.en data/valid.bpe.de \
        --valid-script-path "bash ./scripts/validate.sh" \
        --valid-translation-output data/valid.bpe.en.output --quiet-translation \
        --beam-size 12 --normalize=1 \
        --valid-mini-batch 64 \
        --overwrite --keep-best \
        --early-stopping 5 --after-epochs $EPOCHS --cost-type=ce-mean-words \
        --log model/ens$i/train.log --valid-log model/ens$i/valid.log \
        --enc-depth 6 --dec-depth 6 \
        --tied-embeddings-all \
        --transformer-dropout 0.1 --label-smoothing 0.1 \
        --learn-rate 0.0003 --lr-warmup 16000 --lr-decay-inv-sqrt 16000 --lr-report \
        --optimizer-params 0.9 0.98 1e-09 --clip-norm 5 \
        --devices $GPUS --sync-sgd --seed $i$i$i$i  \
        --exponential-smoothing
done

for i in $(seq 1 $N)
do
  mkdir -p model/ens-rtl$i
  # train model
    $MARIAN_TRAIN \
        --model model/ens-rtl$i/model.npz --type transformer \
        --train-sets data/all.bpe.en data/all.bpe.de \
        --max-length 100 \
        --vocabs model/vocab.ende.yml model/vocab.ende.yml \
        --mini-batch-fit -w $WORKSPACE --mini-batch 1000 --maxi-batch 1000 \
        --valid-freq 5000 --save-freq 5000 --disp-freq 500 \
        --valid-metrics ce-mean-words perplexity translation \
        --valid-sets data/valid.bpe.en data/valid.bpe.de \
        --valid-script-path  "bash ./scripts/validate.sh" \
        --valid-translation-output data/valid.bpe.en.output --quiet-translation \
        --beam-size 12 --normalize=1 \
        --valid-mini-batch 64 \
        --overwrite --keep-best \
        --early-stopping 5 --after-epochs $EPOCHS --cost-type=ce-mean-words \
        --log model/ens-rtl$i/train.log --valid-log model/ens-rtl$i/valid.log \
        --enc-depth 6 --dec-depth 6 \
        --tied-embeddings-all \
        --transformer-dropout 0.1 --label-smoothing 0.1 \
        --learn-rate 0.0003 --lr-warmup 16000 --lr-decay-inv-sqrt 16000 --lr-report \
        --optimizer-params 0.9 0.98 1e-09 --clip-norm 5 \
        --devices $GPUS --sync-sgd --seed $i$i$i$i$i \
        --exponential-smoothing --right-left
done

# translate test sets
for prefix in valid test2014 test2015 test2017
do
    cat data/$prefix.bpe.en \
        | $MARIAN_DECODER -c model/ens1/model.npz.best-translation.npz.decoder.yml \
          -m model/ens?/model.npz.best-translation.npz -d $GPUS \
          --mini-batch 16 --maxi-batch 100 --maxi-batch-sort src -w 5000 --n-best --beam-size $B \
        > data/$prefix.bpe.en.output.nbest.0

    for i in $(seq 1 $N)
    do
      $MARIAN_SCORER -m model/ens-rtl$i/model.npz.best-perplexity.npz \
        -v model/vocab.ende.yml model/vocab.ende.yml -d $GPUS \
        --mini-batch 16 --maxi-batch 100 --maxi-batch-sort trg --n-best --n-best-feature R2L$(expr $i - 1) \
        -t data/$prefix.bpe.en data/$prefix.bpe.en.output.nbest.$(expr $i - 1) > data/$prefix.bpe.en.output.nbest.$i
    done

    cat data/$prefix.bpe.en.output.nbest.$N \
      | python scripts/rescore.py \
      | perl -pe 's/@@ //g' \
      | ../tools/moses-scripts/scripts/recaser/detruecase.perl \
      | ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl > data/$prefix.en.output
done

# calculate bleu scores on test sets
LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt16 -l en-de < data/valid.en.output
LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt14 -l en-de < data/test2014.en.output
LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt15 -l en-de < data/test2015.en.output
LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt17 -l en-de < data/test2017.en.output
