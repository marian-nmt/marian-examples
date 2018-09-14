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

if not exist ../tools/moses-scripts set MISSING_TOOLS=1
if not exist ../tools/subword-nmt set MISSING_TOOLS=1
if not exist ../tools/sacreBLEU set MISSING_TOOLS=1
if "%MISSING_TOOLS%"=="1" (
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
    wsl LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt13 -l en-de --echo src > data/valid.en
    wsl LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt13 -l en-de --echo ref > data/valid.de

    wsl LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt14 -l en-de --echo src > data/test2014.en
    wsl LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt15 -l en-de --echo src > data/test2015.en
    wsl LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt16 -l en-de --echo src > data/test2016.en

    wsl ./scripts/preprocess-data.sh
)

:: create common vocabulary
if not exist "model/vocab.ende.yml" (
    wsl cat data/corpus.bpe.en data/corpus.bpe.de | %MARIAN%\marian-vocab --max-size 36000 > model/vocab.ende.yml
)

:: train model
if not exist "model/model.npz" (
    echo -- Training --
    %MARIAN%\marian.exe ^
        --model model/model.npz --type transformer ^
        --train-sets data/corpus.bpe.en data/corpus.bpe.de ^
        --max-length 100 ^
        --vocabs model/vocab.ende.yml model/vocab.ende.yml ^
        --mini-batch-fit -w 6000 --maxi-batch 1000 ^
        --early-stopping 10 --cost-type=ce-mean-words ^
        --valid-freq 5000 --save-freq 5000 --disp-freq 500 ^
        --valid-metrics ce-mean-words perplexity translation ^
        --valid-sets data/valid.bpe.en data/valid.bpe.de ^
        --valid-script-path .\scripts\validate.bat ^
        --valid-translation-output data/valid.bpe.en.output --quiet-translation ^
        --valid-mini-batch 64 ^
        --beam-size 6 --normalize 0.6 ^
        --log model/train.log --valid-log model/valid.log ^
        --enc-depth 6 --dec-depth 6 ^
        --transformer-heads 8 ^
        --transformer-postprocess-emb d ^
        --transformer-postprocess dan ^
        --transformer-dropout 0.1 --label-smoothing 0.1 ^
        --learn-rate 0.0003 --lr-warmup 16000 --lr-decay-inv-sqrt 16000 --lr-report ^
        --optimizer-params 0.9 0.98 1e-09 --clip-norm 5 ^
        --tied-embeddings-all ^
        --devices %GPUS% --sync-sgd --seed 1111 ^
        --exponential-smoothing
)
if not exist "model/model.npz" (
    echo ERROR: the model has not been trained
    goto :eof
)


echo --- Find best model on dev set
for /f "delims=" %%a in ('wsl cat model/valid.log ^| wsl grep translation ^| wsl sort -rg -k8^,8 -t" " ^| wsl cut -f4 -d" " ^| wsl head -n1') do set ITER=%%a
echo    The best model is model/model.iter%ITER%.npz

echo --- Translate Test set
for %%p in (test2014,test2015,test2016) do (

    type data/%%p.bpe.en ^
        |  %MARIAN%\marian-decoder.exe ^
            --config model/model.npz.decoder.yml ^
            --models model/model.iter%ITER%.npz ^
            --devices %GPUS% ^
            --beam-size 12 --normalize ^
        | wsl sed 's/\@\@ //g' ^
        | wsl ../tools/moses-scripts/scripts/recaser/detruecase.perl ^
        | wsl ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l de ^
        > data/%%p.de.output
)

echo.
echo.
echo Calculate bleu scores on test sets
echo.
wsl LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt14 -l en-de < data/test2014.de.output
wsl LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt15 -l en-de < data/test2015.de.output
wsl LC_ALL=C.UTF-8 ../tools/sacreBLEU/sacrebleu.py -t wmt16 -l en-de < data/test2016.de.output
