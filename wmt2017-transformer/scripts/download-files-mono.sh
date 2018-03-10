#!/bin/bash -v

mkdir -p data
cd data

# get En-De training data for WMT17
wget -nc http://data.statmt.org/wmt17/translation-task/news.2016.de.shuffled.gz

zcat news.2016.de.shuffled.gz | shuf -n 11000000 | perl -ne 'print if(split(/\s/, $_) < 100)' | head -n 10000000 > news.2016.de

# clean
rm -r news.2016.de.shuffled.gz

cd ..
