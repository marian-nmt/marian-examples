# Intro to Transformers

This tutorial is designed to help you train your first machine translation
model. To follow along, you'll need a Linux-based system and an NVIDIA GPU.

In this example we will use Marian to create a English-German translation
system. We'll follow a very simple pipeline with data acquisition, some basic
corpus cleaning, generation of vocabulary with [SentencePiece], training of a
transformer model, and evaluation with [sacreBLEU], and (optionally) [Comet].

We'll be using a subset of data from the WMT21 [news task] to train our model.
For the validation and test sets, we'll use the test sets from WMT19 and WMT20,
respectively.

Lets get started by installing our dependencies!


## Install requirements
If you haven't installed the common tools for `marian-examples`, you can do
by doing to the `tools/` folder in the root of the repository and running `make`.
```shell
cd ../tools
make all
cd -
```
In this example, we'll be using some
[scripts](https://github.com/marian-nmt/moses-scripts) from [Moses].

We'll also use [sacreBLEU] and [Comet] from Python pip. To install these in a
virtual environment, execute:
```shell
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```
You can skip the first two of these commands if you don't want to use a virtual
environment.

Next we'll install Marian!


## Getting Marian
The development version of Marian can be obtained with
```shell
git clone https://github.com/marian-nmt/marian-dev
cd marian-dev
```

### Compile
To compile Marian we need to ensure we have the required packages. The list of
requirements can be found in the [documentation][install_marian]. Since we're
using SentencePiece, we also need to make sure we have satisfy its
[requirements][install_sentencepiece] too.

Then we can compile with
```shell
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_SENTENCEPIECE=ON
cmake --build .
```

To speed up compilation we can use ```cmake --build . -j 8``` to run 8 tasks
simultaneously. You may need to reduce this based on your system CPU and
available memory.

If it succeeded, running
```shell
./marian --version
```
will return the version you've compiled. To verify that Sentence support was enabled, running
```shell
./marian --help |& grep sentencepiece
```
will display the SentencePiece specific options:
```
--sentencepiece-alphas VECTOR ...     Sampling factors for SentencePiece vocabulary; i-th factor corresponds to i-th vocabulary
--sentencepiece-options TEXT          Pass-through command-line options to SentencePiece trainer
--sentencepiece-max-lines UINT=2000000
                                      Maximum lines to train SentencePiece vocabulary, selected with sampling from all data. When set to 0 all lines are going to be used.
```

## Running the Example
The entire example can be run end-to-end by executing
```shell
./run-me.sh
```
This will acquire the data then apply cleaning. It uses the resulting corpus to
train a transformer model, which is evaluated via sacreBLEU.

By default, `run-me.sh` will run on a single GPU (`device 0`). To use a
different set of GPUs, pass their IDs as an argument, e.g. training using the 4
GPUs
```shell
./run-me.sh 0 1 2 3
```

You can run the commands from `run-me.sh` manually yourself. We'll walk through
the different commands in the sections below. These commands assume that Marian
is compiled, and accessible at `../../build/marian`. The `data/`, `scripts/` and
`model/` directories will be contains at the same level as this README file.

## Acquire data
We'll acquire a subset of the data from the WMT21 [news task].

In particular we'll make use of the following English-German parallel corpora:

| Dataset             |     Sentences |
|---------------------|--------------:|
| Europarl v10        |     1,828,521 |
| News Commentary v16 |       398,981 |
| Common Crawl corpus |     2,399,123 |
| **Total**           | **4,626,625** |

### Download
We'll store our data inside the `data/` directory. First lets change directory
to that location:
```shell
cd data
```

To download the datasets above, we can use the command:
```shell
# Get en-de for training WMT21
wget -nc https://www.statmt.org/europarl/v10/training/europarl-v10.de-en.tsv.gz 2> /dev/null
wget -nc https://data.statmt.org/news-commentary/v16/training/news-commentary-v16.de-en.tsv.gz 2> /dev/null
wget -nc https://www.statmt.org/wmt13/training-parallel-commoncrawl.tgz 2> /dev/null
```
This may take a little time to download the data from the server.

The dev set and test set can be obtained directly from sacrebleu via the command line. We echo the source and reference texts to file.
```
# Dev Sets
sacrebleu -t wmt19 -l en-de --echo src > valid.en
sacrebleu -t wmt19 -l en-de --echo ref > valid.de

# Test Sets
sacrebleu -t wmt20 -l en-de --echo src > test.en
sacrebleu -t wmt20 -l en-de --echo ref > test.de
```
This is relatively fast as these are typically only 1000-2000 lines.


### Combine
Now we want to combine our data sources in to a single corpus. First we start by
decompressing each of the EuroParl and news-commentary TSV files.
```shell
for compressed in europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv; do
  if [ ! -e $compressed ]; then
    gzip --keep -q -d $compressed.gz
  fi
done
```
This leaves two TSV files:
  - `europarl-v10.de-en.tsv`
  - `news-commentary-v16.de-en.tsv`

where the first field contains German text, and the second field contains
English text.

We can untar the common crawl archive.
```shell
tar xf training-parallel-commoncrawl.tgz
```
This contains a collection of parallel text files across multiple languages, but
we're only interested in those covering `en-de`:
  - `commoncrawl.de-en.de`
  - `commoncrawl.de-en.de`

From these we can construct a parallel corpus. We concatenate the two TSV files,
and extract the first field to populate the German combined corpus, and then the
second field to populate the English combined corpus. To this, we then
concatenate the commoncrawl data to the relevant file.
```shell
# Corpus
if [ ! -e corpus.de ] || [ ! -e corpus.en ]; then
  # TSVs
  cat europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv | cut -f 1 > corpus.de
  cat europarl-v10.de-en.tsv news-commentary-v16.de-en.tsv | cut -f 2 > corpus.en

  # Plain text
  cat commoncrawl.de-en.de >> corpus.de
  cat commoncrawl.de-en.en >> corpus.en
fi
```

## Prepare data
With our combined corpus we now apply some basic pre-processing.

Firstly, we remove any non-printing characters using a script from [Moses].
```shell
for lang in en de; do
  # Remove non-printing characters
  cat corpus.$lang \
    | perl $MOSES_SCRIPTS/tokenizer/remove-non-printing-char.perl \
    > .corpus.norm.$lang
done
```
This modifies the content separately for each language, but **does not** adjust
the ordering. The parallel sentences pairs are associated by line, so it is
crucial that any pre-processing preserves that.

Then we constrain the sentences to be between 1 and 100 words with
```shell
# Contrain length between 1 100
perl $MOSES_SCRIPTS/training/clean-corpus-n.perl .corpus.norm en de .corpus.trim 1 100
```
This removes sentence pairs where either one does not meet the length
requirements.

To remove any duplicates we build a TSV file, sort it and retain only unique
lines.
```shell
# Deduplicate
paste <(cat .corpus.trim.en) <(cat .corpus.trim.de) \
  | LC_ALL=C sort -S 50% | uniq \
  > .corpus.uniq.ende.tsv
```

Then clean corpus is obtained by separating our TSV file back to parallel text
files.
```shell
cat .corpus.uniq.ende.tsv | cut -f 1 > corpus.clean.en
cat .corpus.uniq.ende.tsv | cut -f 2 > corpus.clean.de
```

The cleaned corpus has 4,552,319 parallel sentences, having discarded around
1.6% the total sentences.

## Training
To train a transformer model, we make use of Marian's presets. The `--task
transformer-base` preset gives a good baseline of hyperparameters for a
transformer model.

We'll put our configuration inside a YAML file `transformer-model.yml`. We can
output the configuration for this preset using the `--dump-config expand`
options:
```shell
$MARIAN/marian --task transformer-base --dump-config expand > transformer-model.yml
```
We have shortened `../../build/marian` to `$MARIAN/marian` for brevity.

You can inspect this file to see exactly which options have been set.

We'll modify this file by adding options that training a little more verbose.
```
disp-freq: 1000
disp-first: 10
save-freq: 2ku
```

We also add line that will halt training after 10 updates without an improvement
for on the validation set.
```
early-stopping: 10
```

We will also validate with additional metrics, keep the best model per metric
and validate more often. This is achieved via:
```
keep-best: true
valid-freq: 2ku
valid-metrics:
  - ce-mean-words
  - bleu
  - perplexity
```
Note that early-stopping criteria applies to `ce-mean-words`.

### SentencePiece (Optional)
To generate a SentencePiece vocabulary model you can run the `spm_train` command
built alongside Marian. An example invocation would look something like:
```shell
 $MARIAN/spm_train \
  --accept_language en,de \
  --input data/corpus.clean.en,data/corpus.clean.de \
  --model_prefix model/vocab.ende \
  --vocab_size 32000
mv model/vocab.ende.{model,spm}
```
Where as a last step, we rename `.model` to `.spm` (SentencePiece Model) so that
Marian recognises it as from SentencePiece. This step is listed as optional as
in the absence of a vocabulary file, Marian will build one.

This produces a combined vocabulary of 32000 tokens.

### Training Command
To begin training, we call the `marian` command with the following arguments:
```shell
$MARIAN/marian -c transformer-model.yml \
  -d 0 1 2 3 --workspace 9000 \
  --seed 1111 \
  --after 10e \
  --model model/model.npz \
  --train-sets data/corpus.clean.{en,de} \
  --vocabs model/vocab.ende.spm model/vocab.ende.spm \
  --dim-vocabs 32000 32000 \
  --valid-sets data/valid.{en,de} \
  --log model/train.log --valid-log model/valid.log
```
The flag `-d` sets the devices to be ran on, which you'll have to update for
your setup. Additionally `-w`, the workspace, depends on how much memory your
GPUs have. The example was tested on a pair of NVIDIA RTX 2080 with 11GB using a
workspace of 9000 MiB. You should reduce this if you have less available memory.
For reproducibility, the seed is set to `1111`. As a reference, this took around
8 hours.

The models will be stored at `model/model.npz`. The training and validation sets
are specified, as well as the vocabular files and their dimension. Logs for the
training and validation output are also retained. Finally, for this example we
only train for a maximum of 10 epochs.

The `save-freq` we specified of 2000, will result in the model state being saved
at regular intervals of 2000 updates:
  - `model/model.iter2000.npz`
  - `model/model.iter4000.npz`
  - ...

The current model is always `model/model.npz`. Additionally, the `keep-best`
option produces an additional model file for every validator:
  - `model/model.npz.best-bleu.npz`
  - `model/model.npz.best-ce-mean-words.npz`
  - `model/model.npz.best-perplexity.npz`

The training progress is tracked in `model/model.npz.progress.yml` with the full
model configuration at `model/model.npz.yml`. In addition, Marian automatically
generates a decoding config for each of these models:
  - `model/model.npz.decoder.yml`
  - `model/model.npz.best-*.npz.decoder.yml`

These conveniently refer to the model and vocabulary files. They also include a
default setting for beam-search and normalization, which can be overwritten by
the command-line interface.

## Translation
To translate we use the `marian-decoder` command:
```shell
cat data/test.en \
  | $MARIAN/marian-decoder \
      -c model/model.npz.best-bleu.npz.decoder.yml \
      -d 0 1 2 3 \
  | tee evaluation/testset_output.txt \
  | sacrebleu data/test.de --metrics bleu chrf -b -w 3 -f text
```
where we're using the model that produced the best BLEU score on the validation
set. This snippet passes the source text to Marian over a pipe to `stdin`, and
is output over `stdout`. We're capturing this output to file with `tee`, and
passing the output into sacreBLEU for evaluation. We provide sacreBLEU our
reference text, and ask it to compute both BLEU and chrF. The remaining
sacreBLEU options return us only the score with 3 decimal places of precision in
text format.

You can experiment changing the `--beam-size` and `--normalization` to see how
it changes the scores


Additionally, if you want to compute the Comet score, there's a helper script:
```
./scripts/comet-score.sh hyp.txt src.txt ref.txt
```
This returns the Comet score for `hyp.txt`, the translation output, based on
`src.txt` the source input, and `ref.txt` the reference translation.

### Results
Here we tabulate the scores for BLEU, chrF2 and Comet for our model. For each of
the metrics, a larger score is better. You should achieve similar results with
your own run!

These are the results from decoding with best-BLEU model:

| Test   | BLEU   | chrF2  | Comet  |
|--------|--------|--------|--------|
| WMT20  | 24.573 | 52.368 | 0.1795 |
| WMT19^ | 37.185 | 62.628 | 0.3312 |
| WMT18  | 40.140 | 65.281 | 0.5363 |
| WMT17  | 26.832 | 56.096 | 0.4061 |
| WMT16  | 33.245 | 60.534 | 0.4552 |

**^** Note that WMT19 was used as the validation set!

## Going Further
If you want to improve on these results, you can continue training for longer,
or incorporating other datasets from the WMT21 task. Take a look at the other
examples and think about implementing some data augmentation through
back-translation.

Good luck!

<!-- Links -->
[sacrebleu]: https://github.com/mjpost/sacrebleu
[comet]: https://github.com/Unbabel/COMET
[moses]: https://github.com/moses-smt/mosesdecoder

[news task]: https://www.statmt.org/wmt21/translation-task.html

[sentencepiece]: https://github.com/google/sentencepiece
[install_marian]: https://marian-nmt.github.io/docs/#installation
[install_sentencepiece]: https://marian-nmt.github.io/docs/#sentencepiece
