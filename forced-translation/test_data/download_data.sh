#!/bin/bash

# exit when any command fails
set -e

# download Europarl for en-pt
wget https://object.pouta.csc.fi/OPUS-Europarl/v8/moses/en-pt.txt.zip -O en-pt.txt.zip
unzip en-pt.txt.zip Europarl.en-pt.en Europarl.en-pt.pt

# split corpus between train dev and test sets
paste Europarl.en-pt.en Europarl.en-pt.pt | shuf > shuffled_corpus

head -n 2000 shuffled_corpus > valid
head -n 4000 shuffled_corpus | tail -n 2000 > test
tail -n +4000 shuffled_corpus > training

cut -f 1 training > train.en
cut -f 2 training > train.pt
cut -f 1 valid > valid.en
cut -f 2 valid > valid.pt
cut -f 1 test > test.en
cut -f 2 test > test.pt

rm shuffled_corpus valid test training en-pt.txt.zip Europarl.en-pt.en Europarl.en-pt.pt
