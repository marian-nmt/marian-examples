#!/bin/bash

cat $1 \
    | sed 's/\@\@ //g' \
    | ../tools/moses-scripts/scripts/recaser/detruecase.perl 2> /dev/null \
    | ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l en 2>/dev/null \
    | ../tools/moses-scripts/scripts/generic/multi-bleu-detok.perl data/newsdev2016.en \
    | sed -r 's/BLEU = ([0-9.]+),.*/\1/'
