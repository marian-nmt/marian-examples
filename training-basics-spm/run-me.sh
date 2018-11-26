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
    echo "marian is not installed in $MARIAN/build, you need to compile the toolkit first"
    exit 1
fi

# get our fork of sacrebleu
git clone https://github.com/marian-nmt/sacreBLEU.git sacreBLEU

# create dev set
sacreBLEU/sacrebleu.py -t wmt16/dev -l ro-en --echo src > data/newsdev2016.ro
sacreBLEU/sacrebleu.py -t wmt16/dev -l ro-en --echo ref > data/newsdev2016.en

# create test set
sacreBLEU/sacrebleu.py -t wmt16 -l ro-en --echo src > data/newstest2016.ro
sacreBLEU/sacrebleu.py -t wmt16 -l ro-en --echo ref > data/newstest2016.en

if [ ! -e "data/corpus.ro" ]
then
    # change into data directory
    cd data

    # get En-Ro training data for WMT16
    wget -nc http://www.statmt.org/europarl/v7/ro-en.tgz
    wget -nc http://opus.lingfil.uu.se/download.php?f=SETIMES2/en-ro.txt.zip -O SETIMES2.ro-en.txt.zip
    wget -nc http://data.statmt.org/rsennrich/wmt16_backtranslations/ro-en/corpus.bt.ro-en.en.gz
    wget -nc http://data.statmt.org/rsennrich/wmt16_backtranslations/ro-en/corpus.bt.ro-en.ro.gz

    # extract data
    tar -xf ro-en.tgz
    unzip SETIMES2.ro-en.txt.zip
    gzip -d corpus.bt.ro-en.en.gz corpus.bt.ro-en.ro.gz

    # create corpus files
    cat europarl-v7.ro-en.en SETIMES2.en-ro.en corpus.bt.ro-en.en > corpus.en
    cat europarl-v7.ro-en.ro SETIMES2.en-ro.ro corpus.bt.ro-en.ro > corpus.ro

    # clean
    rm ro-en.tgz SETIMES2.* corpus.bt.* europarl-*

    # change back into main directory
    cd ..
fi


# create the model folder
mkdir -p model

# train model
$MARIAN/build/marian \
    --devices $GPUS \
    --type s2s \
    --model model/model.npz \
    --train-sets data/corpus.ro data/corpus.en \
    --vocabs model/vocab.roen.spm model/vocab.roen.spm \
    --sentencepiece-options '--normalization_rule_tsv=data/norm_romanian.tsv' \
    --dim-vocabs 32000 32000 \
    --mini-batch-fit -w 5000 \
    --layer-normalization --tied-embeddings-all \
    --dropout-rnn 0.2 --dropout-src 0.1 --dropout-trg 0.1 \
    --early-stopping 5 --max-length 100 \
    --valid-freq 10000 --save-freq 10000 --disp-freq 1000 \
    --cost-type ce-mean-words --valid-metrics ce-mean-words bleu-detok \
    --valid-sets data/newsdev2016.ro data/newsdev2016.en \
    --log model/train.log --valid-log model/valid.log --tempdir model \
    --overwrite --keep-best \
    --seed 1111 --exponential-smoothing \
    --normalize=0.6 --beam-size=6 --quiet-translation

# translate dev set
cat data/newsdev2016.ro \
    | $MARIAN/build/marian-decoder -c model/model.npz.best-bleu-detok.npz.decoder.yml -d $GPUS -b 6 -n0.6 \
      --mini-batch 64 --maxi-batch 100 --maxi-batch-sort src > data/newsdev2016.ro.output

# translate test set
cat data/newstest2016.ro \
    | $MARIAN/build/marian-decoder -c model/model.npz.best-bleu-detok.npz.decoder.yml -d $GPUS -b 6 -n0.6 \
      --mini-batch 64 --maxi-batch 100 --maxi-batch-sort src > data/newstest2016.ro.output

# calculate bleu scores on dev and test set
sacreBLEU/sacrebleu.py -t wmt16/dev -l ro-en < data/newsdev2016.ro.output
sacreBLEU/sacrebleu.py -t wmt16 -l ro-en < data/newstest2016.ro.output
