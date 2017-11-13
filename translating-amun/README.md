Example for translating with Amun
=================================

The example demonstrates how to translate with Amun using Edinburgh's
German-English WMT2016 single model and ensemble.

To execute the complete example type:

```
./run-me.sh
```

which downloads Edinburgh's WMT16 English-Germain pretrained models from
<http://data.statmt.org/rsennrich/wmt16_systems>, and next translates the WMT15
test set with the single best model and with a 4-model ensemble.

The test set is processed before and after translation (tokenization,
truecasing, segmentation into subwords units).

To use with a different GPU than device 0 or more GPUs (here 0 1 2 3) type the
command below.

```
./run-me.sh 0 1 2 3
```

## Details

### Translate with a single model

First, we translate the WMT15 test set with a single model using only command
line options. Here, batched decoding is used with a mini-batch size of 50, i.e.
50 sentences are being translated at once, while 1000 sentence are being
preloaded so they can be organized into length-based batches:

```
# translate test set with single model
cat data/newstest2015.ende.en | \
    # preprocess
    ../tools/moses-scripts/scripts/tokenizer/normalize-punctuation.perl -l en | \
    ../tools/moses-scripts/scripts/tokenizer/tokenizer.perl -l en -penn | \
    ../tools/moses-scripts/scripts/recaser/truecase.perl -model en-de/truecase-model.en | \
    # translate
    ../../build/amun -m en-de/model.npz -s en-de/vocab.en.json -t en-de/vocab.de.json \
        --mini-batch 50 --maxi-batch 1000 -b 12 -n --bpe en-de/ende.bpe | \
    # postprocess
    ../tools/moses-scripts/scripts/recaser/detruecase.perl | \
    ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l de > data/newstest2015.single.out
```

### Create a configuration file using command line options

We can use `amun` to create a configuration file for us by providing command line
parameters and saving them into a YAML file with `--dump-config`:

```
../../build/amun -m en-de/model-ens?.npz -s en-de/vocab.en.json -t en-de/vocab.de.json \
    --mini-batch 1 --maxi-batch 1 -b 12 -n --bpe en-de/ende.bpe \
    --relative-paths --dump-config > ensemble.yml
```

### Translate with configuration file

Such a configuration file can then be used instead of the command line arguments:

```
# translate test set with ensemble
cat data/newstest2015.ende.en | \
    # preprocess
    ../tools/moses-scripts/scripts/tokenizer/normalize-punctuation.perl -l en | \
    ../tools/moses-scripts/scripts/tokenizer/tokenizer.perl -l en -penn | \
    ../tools/moses-scripts/scripts/recaser/truecase.perl -model en-de/truecase-model.en | \
    # translate
    ../../build/amun -c ensemble.yml | \
    # postprocess
    ../tools/moses-scripts/scripts/recaser/detruecase.perl | \
    ../tools/moses-scripts/scripts/tokenizer/detokenizer.perl -l de > data/newstest2015.ensemble.out
```
