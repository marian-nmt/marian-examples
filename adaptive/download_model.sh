#!/bin/bash
set -euo

rm -r ./marian-model

wget https://object.pouta.csc.fi/OPUS-MT-models/en-lt/opus-2019-12-04.zip -O ./model.zip
unzip ./model.zip -d ./marian-model && rm ./model.zip

# Use "model" config key instead of "models"
gawk -i inplace -v RS="" '{gsub(/models:\n  -/,"model:");}1' ./marian-model/decoder.yml
