#!/usr/bin/env bash
set -euo pipefail

cd data
echo "Downloading data"
# Get en-de for training WMT21
wget -nc https://www.statmt.org/europarl/v10/training/europarl-v10.de-en.tsv.gz 2> /dev/null
wget -nc https://data.statmt.org/news-commentary/v16/training/news-commentary-v16.de-en.tsv.gz 2> /dev/null
wget -nc https://www.statmt.org/wmt13/training-parallel-commoncrawl.tgz 2> /dev/null

# Dev Sets
sacrebleu -t wmt19 -l en-de --echo src > valid.en
sacrebleu -t wmt19 -l en-de --echo ref > valid.de

# Test Sets
sacrebleu -t wmt20 -l en-de --echo src > test.en
sacrebleu -t wmt20 -l en-de --echo ref > test.de

# Uncompress
for compressed in europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv; do
  if [ ! -e $compressed ]; then
    gzip --keep -q -d $compressed.gz
  fi
done

tar xf training-parallel-commoncrawl.tgz

# Corpus
if [ ! -e corpus.de ] || [ ! -e corpus.en ]; then
  # TSVs
  cat europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv | cut -f 1 > corpus.de
  cat europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv | cut -f 2 > corpus.en

  # Plain text
  cat commoncrawl.de-en.de >> corpus.de
  cat commoncrawl.de-en.en >> corpus.en
fi

echo "Corpus prepared"
