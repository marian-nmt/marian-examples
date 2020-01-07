#!/bin/bash -v

##################################################################

DEC_DEPTH=6
GPUS='0 1 2 3'

##################################################################

MARIAN=../../build

# if we are in WSL, we need to add '.exe' to the tool names
if [ -e "/bin/wslpath" ]
then
    EXT=.exe
fi

MARIAN_TRAIN=$MARIAN/marian$EXT
MARIAN_DECODER=$MARIAN/marian-decoder$EXT
MARIAN_CONV=$MARIAN/marian-conv$EXT

if [ ! -e $MARIAN_TRAIN ]
then
    echo "marian is not installed in $MARIAN, you need to compile the toolkit first"
    exit 1
fi

# set chosen gpus
if [ $# -ne 0 ]
then
    GPUS=$@
fi
echo Using GPUs: $GPUS

mkdir -p model

if [ ! -e "model/model.npz.best-bleu-detok.npz" ]
then
    $MARIAN_TRAIN \
        --devices $GPUS \
        --task transformer-base \
        --model model/model.npz \
        --train-sets data/noisybt.merge.train.4.filtered.{en,de} \
        --vocabs data/vocab.ende.{spm,spm} \
        --early-stopping 10 --max-length 256 \
        --valid-freq 5000 --save-freq 5000 --disp-freq 500 \
        --valid-metrics bleu-detok ce-mean-words \
        --valid-sets data/valid.{en,de} \
        --log model/train.log --valid-log model/valid.log \
        --overwrite --keep-best \
        --seed 1234 --exponential-smoothing --quiet-translation \
        --transformer-dropout 0.1 --label-smoothing 0 \
        --transformer-decoder-autoreg rnn --dec-cell ssru \
        --transformer-tied-layers 1 1 1 1 1 1 --dec-depth $DEC_DEPTH
fi

if [ ! -e "model/model.npz.best-bleu-detok.8.bin" ]
then
    $MARIAN_CONV -f model/model.npz.best-bleu-detok.npz -t model/model.npz.best-bleu-detok.8.bin -g packed8avx512
fi
