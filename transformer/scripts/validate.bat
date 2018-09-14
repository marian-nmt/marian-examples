@echo off
setlocal

set TRANSLATED_PATH=%1
set WSLENV=TRANSLATED_PATH/up

wsl cat $TRANSLATED_PATH ^
    | wsl sed 's/\@\@ //g' ^
    | wsl ../tools/moses-scripts/scripts/recaser/detruecase.perl 2>NUL ^
    | wsl ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l en 2>NUL ^
    | wsl ../tools/moses-scripts/scripts/generic/multi-bleu-detok.perl data/newsdev2016.en ^
    | wsl sed -r 's/BLEU = ([0-9.]+),.*/\1/'
