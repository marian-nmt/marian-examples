@echo off
setlocal

set EXAMPLE_ROOT=%~dp0
set MARIAN=..\..\marian-dev\vs\build-vs\Release

:: set chosen GPU
set GPUS=0
if not "%*" == "" (
    set GPUS=%*
)
echo Using GPUs: %GPUS%

if not exist %MARIAN%\marian.exe (
    echo marian is not installed in %MARIAN%, you need to compile the toolkit first
    exit /b 1
)

if not exist ../tools/moses-scripts (
    echo missing tools in ../tools, you need to download them first
    exit /b 1
)

:: download files
if not exist "data/corpus.en" (
    wsl ./scripts/download-files.sh
)

if not exist model mkdir model

:: preprocess data
if not exist "data/corpus.bpe.en" (
    wsl ./scripts/preprocess-data.sh
)

:: train model
if not exist "model/model.npz.best-translation.npz" (
    if not exist tmp mkdir tmp

    echo -- Training --
    %MARIAN%\marian.exe ^
        --devices %GPUS% ^
        --type amun ^
        --model model/model.npz ^
        --train-sets data/corpus.bpe.ro data/corpus.bpe.en ^
        --vocabs model/vocab.ro.yml model/vocab.en.yml ^
        --dim-vocabs 66000 50000 ^
        --mini-batch-fit -w 3000 ^
        --layer-normalization --dropout-rnn 0.2 --dropout-src 0.1 --dropout-trg 0.1 ^
        --early-stopping 5 ^
        --valid-freq 10000 --save-freq 10000 --disp-freq 1000 ^
        --valid-metrics cross-entropy translation ^
        --valid-sets data/newsdev2016.bpe.ro data/newsdev2016.bpe.en ^
        --valid-script-path .\scripts\validate.bat ^
        --log model/train.log --valid-log model/valid.log ^
        --overwrite --keep-best ^
        --seed 1111 --exponential-smoothing ^
        --normalize=1 --beam-size=12 --quiet-translation
)
if not exist "model/model.npz.best-translation.npz" (
    echo ERROR: the model has not been trained
    exit /b 1
)


echo.
echo -- Translate Dev set --

wsl cat data/newsdev2016.bpe.ro ^
    | %MARIAN%\marian-decoder.exe ^
        --config model/model.npz.best-translation.npz.decoder.yml ^
        --devices %GPUS% ^
        --normalize=1 --beam-size=12 --quiet-translation ^
        --mini-batch 64 --maxi-batch 10 --maxi-batch-sort src ^
    | wsl sed 's/\@\@ //g' ^
    | wsl ../tools/moses-scripts/scripts/recaser/detruecase.perl ^
    | wsl ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l en ^
    > data/newsdev2016.ro.output


echo.
echo -- Translate Test set --

wsl cat data/newstest2016.bpe.ro ^
    | %MARIAN%\marian-decoder.exe ^
        --config model/model.npz.best-translation.npz.decoder.yml ^
        --devices %GPUS% ^
        --normalize=1 --beam-size=12 --quiet-translation ^
        --mini-batch 64 --maxi-batch 10 --maxi-batch-sort src ^
    | wsl sed 's/\@\@ //g' ^
    | wsl ../tools/moses-scripts/scripts/recaser/detruecase.perl ^
    | wsl ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l en ^
    > data/newstest2016.ro.output

echo.
echo.
echo BLEU score for Dev set
wsl ../tools/moses-scripts/scripts/generic/multi-bleu-detok.perl data/newsdev2016.en < data/newsdev2016.ro.output
echo BLEU score for Test set
wsl ../tools/moses-scripts/scripts/generic/multi-bleu-detok.perl data/newstest2016.en < data/newstest2016.ro.output
